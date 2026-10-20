-- Run as SUPPORT_AI.
-- Step A: load an in-database ONNX embedding model (no external API, no data leaves the DB).
-- Download Oracle's pre-converted all-MiniLM-L12-v2 ONNX package from the link in Oracle's
-- AI Vector Search documentation, upload it to an OCI Object Storage bucket (pre-authenticated
-- request URL), and paste that URL below.  Model output = 384-dim vectors.
DEFINE onnx_uri = 'https://objectstorage.<region>.oraclecloud.com/p/<PAR>/n/<ns>/b/<bucket>/o/all_MiniLM_L12_v2.onnx'

BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL_CLOUD(
    model_name => 'DOC_MODEL',
    credential => NULL,              -- NULL is fine for a pre-authenticated request URL
    uri        => '&onnx_uri');
END;
/

-- Sanity check: model exists, and produces a 384-dim vector
SELECT model_name, algorithm, mining_function FROM user_mining_models WHERE model_name = 'DOC_MODEL';
SELECT VECTOR_DIMS(VECTOR_EMBEDDING(doc_model USING 'hello world' AS data)) AS dims FROM dual;

-- Step B: chunk each article (sentence-aware, ~100 words, 20 word overlap) and embed in ONE statement.
-- This is the whole "ingestion pipeline" -- pure SQL, set-based, runs next to the data.
INSERT INTO kb_chunk (article_id, chunk_seq, chunk_text, embedding)
SELECT a.article_id,
       c.chunk_id,
       c.chunk_text,
       VECTOR_EMBEDDING(doc_model USING c.chunk_text AS data)
FROM   kb_article a,
       VECTOR_CHUNKS(a.body BY words MAX 100 OVERLAP 20 SPLIT BY sentence
                     LANGUAGE american NORMALIZE all) c;
COMMIT;

SELECT COUNT(*) AS chunks, COUNT(embedding) AS embedded FROM kb_chunk;

-- Step C: approximate-nearest-neighbour index (HNSW, in-memory neighbour graph).
-- On a tiny dataset the optimizer may still choose exact search; the index matters at scale.
-- Alternative for very large tables / limited memory: ORGANIZATION NEIGHBOR PARTITIONS (IVF).
CREATE VECTOR INDEX kb_chunk_hnsw_ix ON kb_chunk (embedding)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE COSINE
  WITH TARGET ACCURACY 95;
