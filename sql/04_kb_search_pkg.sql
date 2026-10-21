-- Run as SUPPORT_AI.
CREATE OR REPLACE PACKAGE kb_search_pkg AS
  -- Hybrid retrieval: semantic similarity + ordinary relational filters
  FUNCTION search(p_query      IN VARCHAR2,
                  p_k          IN PLS_INTEGER DEFAULT 5,
                  p_product_id IN NUMBER      DEFAULT NULL) RETURN SYS_REFCURSOR;

  -- Retrieval Augmented Generation: retrieve -> build grounded prompt -> LLM -> audit
  FUNCTION answer(p_question   IN VARCHAR2,
                  p_k          IN PLS_INTEGER DEFAULT 3,
                  p_product_id IN NUMBER      DEFAULT NULL,
                  p_profile    IN VARCHAR2    DEFAULT 'SUPPORT_GENAI') RETURN CLOB;

  -- Retrieval quality metrics over golden_question; stores a row in eval_run
  PROCEDURE run_eval(p_k IN PLS_INTEGER DEFAULT 3, p_notes IN VARCHAR2 DEFAULT NULL);
END kb_search_pkg;
/

CREATE OR REPLACE PACKAGE BODY kb_search_pkg AS

  FUNCTION search(p_query      IN VARCHAR2,
                  p_k          IN PLS_INTEGER DEFAULT 5,
                  p_product_id IN NUMBER      DEFAULT NULL) RETURN SYS_REFCURSOR IS
    l_qv VECTOR(384, FLOAT32);
    l_rc SYS_REFCURSOR;
  BEGIN
    SELECT VECTOR_EMBEDDING(doc_model USING p_query AS data) INTO l_qv FROM dual;

    OPEN l_rc FOR
      SELECT c.chunk_id,
             c.article_id,
             a.title,
             ROUND(VECTOR_DISTANCE(c.embedding, l_qv, COSINE), 4) AS distance,
             c.chunk_text
      FROM   kb_chunk c
      JOIN   kb_article a ON a.article_id = c.article_id
      WHERE  (p_product_id IS NULL OR a.product_id = p_product_id)
      ORDER  BY VECTOR_DISTANCE(c.embedding, l_qv, COSINE)
      FETCH  APPROX FIRST p_k ROWS ONLY;
    RETURN l_rc;
  END search;

  -- Audit logging runs as an AUTONOMOUS TRANSACTION so that answer() can be called from a SELECT
  -- (a function called from a query may not do DML otherwise: ORA-14551).
  PROCEDURE log_audit(p_question IN VARCHAR2, p_ids IN VARCHAR2, p_answer IN CLOB, p_ms IN NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO rag_audit(question, article_ids, answer, latency_ms)
    VALUES (SUBSTR(p_question,1,1000), p_ids, p_answer, ROUND(p_ms));
    COMMIT;
  END log_audit;

  FUNCTION answer(p_question   IN VARCHAR2,
                  p_k          IN PLS_INTEGER DEFAULT 3,
                  p_product_id IN NUMBER      DEFAULT NULL,
                  p_profile    IN VARCHAR2    DEFAULT 'SUPPORT_GENAI') RETURN CLOB IS
    l_rc       SYS_REFCURSOR;
    l_chunk_id kb_chunk.chunk_id%TYPE;
    l_art_id   kb_article.article_id%TYPE;
    l_title    kb_article.title%TYPE;
    l_dist     NUMBER;
    l_text     CLOB;
    l_context  CLOB;
    l_ids      VARCHAR2(200);
    l_prompt   CLOB;
    l_answer   CLOB;
    l_t0       TIMESTAMP := SYSTIMESTAMP;
    l_ms       NUMBER;
  BEGIN
    l_rc := search(p_question, p_k, p_product_id);
    LOOP
      FETCH l_rc INTO l_chunk_id, l_art_id, l_title, l_dist, l_text;
      EXIT WHEN l_rc%NOTFOUND;
      l_context := l_context || '[KB-' || l_art_id || '] ' || l_title || CHR(10) || l_text || CHR(10) || CHR(10);
      l_ids     := l_ids || CASE WHEN l_ids IS NOT NULL THEN ',' END || l_art_id;
    END LOOP;
    CLOSE l_rc;

    IF l_context IS NULL THEN
      RETURN 'No relevant knowledge base content found.';
    END IF;

    -- Grounding instructions = the main hallucination control
    l_prompt :=
      'You are a support assistant. Answer ONLY from the context below. ' ||
      'Cite the source ids like [KB-3]. If the context does not contain the answer, ' ||
      'say you do not know and suggest escalating to a human agent.' || CHR(10) || CHR(10) ||
      'CONTEXT:' || CHR(10) || l_context || CHR(10) ||
      'QUESTION: ' || p_question;

    l_answer := DBMS_CLOUD_AI.GENERATE(prompt       => l_prompt,
                                       profile_name => p_profile,
                                       action       => 'chat');

    l_ms := EXTRACT(SECOND FROM (SYSTIMESTAMP - l_t0)) * 1000
          + EXTRACT(MINUTE FROM (SYSTIMESTAMP - l_t0)) * 60000;

    log_audit(p_question, l_ids, l_answer, l_ms);
    RETURN l_answer;
  END answer;

  PROCEDURE run_eval(p_k IN PLS_INTEGER DEFAULT 3, p_notes IN VARCHAR2 DEFAULT NULL) IS
    l_rc       SYS_REFCURSOR;
    l_chunk_id kb_chunk.chunk_id%TYPE;
    l_art_id   kb_article.article_id%TYPE;
    l_title    kb_article.title%TYPE;
    l_dist     NUMBER;
    l_text     CLOB;
    l_rank     PLS_INTEGER;
    l_hits     PLS_INTEGER := 0;
    l_n        PLS_INTEGER := 0;
    l_rr_sum   NUMBER := 0;
  BEGIN
    FOR q IN (SELECT question, expected_article_id FROM golden_question) LOOP
      l_n    := l_n + 1;
      l_rank := 0;
      l_rc   := search(q.question, p_k);
      LOOP
        FETCH l_rc INTO l_chunk_id, l_art_id, l_title, l_dist, l_text;
        EXIT WHEN l_rc%NOTFOUND;
        l_rank := l_rank + 1;
        IF l_art_id = q.expected_article_id THEN
          l_hits   := l_hits + 1;
          l_rr_sum := l_rr_sum + 1 / l_rank;   -- reciprocal rank of first correct chunk
          EXIT;
        END IF;
      END LOOP;
      CLOSE l_rc;
    END LOOP;

    INSERT INTO eval_run(embed_model, k, n_questions, recall_at_k, mrr, notes)
    VALUES ('DOC_MODEL (all-MiniLM-L12-v2)', p_k, l_n,
            ROUND(l_hits / NULLIF(l_n,0), 3), ROUND(l_rr_sum / NULLIF(l_n,0), 3), p_notes);
    COMMIT;
  END run_eval;

END kb_search_pkg;
/
SHOW ERRORS
