-- Run as SUPPORT_AI.
-- Step A: load an in-database ONNX embedding model (no external API, no data leaves the DB).
-- Oracle publishes a pre-built all-MiniLM-L12-v2 ONNX file (384-dim vectors). Download it from Oracle's
-- blog post "Use our prebuilt ONNX model now available for embedding generation" (search that title),
-- unzip it, upload all_MiniLM_L12_v2.onnx to a private Object Storage bucket, create a
-- pre-authenticated request (PAR) with read access, and paste the PAR URL below.
DEFINE onnx_uri = 'https://objectstorage.<region>.oraclecloud.com/p/<PAR>/n/<namespace>/b/<bucket>/o/all_MiniLM_L12_v2.onnx'

-- Re-running? If you get ORA-40204 (model already exists), the model is loaded: skip this block,
-- or first run: EXEC DBMS_VECTOR.DROP_ONNX_MODEL('DOC_MODEL', TRUE);
BEGIN
  -- 1) copy the file from Object Storage into the database's DATA_PUMP_DIR directory
  DBMS_CLOUD.GET_OBJECT(
    object_uri     => '&onnx_uri',
    directory_name => 'DATA_PUMP_DIR',
    file_name      => 'all_MiniLM_L12_v2.onnx');

  -- 2) register it as an embedding model named DOC_MODEL
  DBMS_VECTOR.LOAD_ONNX_MODEL(
    directory  => 'DATA_PUMP_DIR',
    file_name  => 'all_MiniLM_L12_v2.onnx',
    model_name => 'DOC_MODEL',
    metadata   => JSON('{"function":"embedding","embeddingOutput":"embedding","input":{"input":["DATA"]}}'));
END;
/

-- Sanity check: model exists, and produces a 384-dim vector
SELECT model_name, algorithm, mining_function FROM user_mining_models WHERE model_name = 'DOC_MODEL';
SELECT VECTOR_DIMS(VECTOR_EMBEDDING(doc_model USING 'hello world' AS data)) AS dims FROM dual;

-- Step B: chunk each article (sentence-aware, ~100 words, 20 word overlap) and embed in ONE statement.
-- This is the whole "ingestion pipeline" -- pure SQL, set-based, runs next to the data.
INSERT INTO kb_chunk (article_id, chunk_seq, chunk_text, embedding)
SELECT a.article_id,
       ROW_NUMBER() OVER (PARTITION BY a.article_id ORDER BY c.chunk_offset),
       c.chunk_text,
       VECTOR_EMBEDDING(doc_model USING c.chunk_text AS data)
FROM   kb_article a,
       VECTOR_CHUNKS(a.body BY words MAX 100 OVERLAP 20 SPLIT BY sentence
                     LANGUAGE american NORMALIZE all) c;
COMMIT;

SELECT COUNT(*) AS chunks FROM kb_chunk;
SELECT COUNT(*) AS embedded FROM kb_chunk WHERE embedding IS NOT NULL;  -- COUNT(vector_col) raises ORA-22849

-- (ORA-00955 on the next statement just means the index already exists.)
-- Step C: approximate-nearest-neighbour index (HNSW, in-memory neighbour graph).
-- On a tiny dataset the optimizer may still choose exact search; the index matters at scale.
-- Alternative for very large tables / limited memory: ORGANIZATION NEIGHBOR PARTITIONS (IVF).
CREATE VECTOR INDEX kb_chunk_hnsw_ix ON kb_chunk (embedding)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE COSINE
  WITH TARGET ACCURACY 95;
