-- Run as SUPPORT_AI.  Measure retrieval quality; re-run after every change (model, chunk size, index).
EXEC kb_search_pkg.run_eval(p_k => 1, p_notes => 'baseline MiniLM, 100-word chunks');
EXEC kb_search_pkg.run_eval(p_k => 3, p_notes => 'baseline MiniLM, 100-word chunks');
EXEC kb_search_pkg.run_eval(p_k => 5, p_notes => 'baseline MiniLM, 100-word chunks');

SELECT run_id, k, n_questions, recall_at_k, mrr, notes FROM eval_run ORDER BY run_id;

-- Manual spot check of one query with a relational filter (Nimbus Billing only):
VAR rc REFCURSOR
EXEC :rc := kb_search_pkg.search('customer paid two times', 3, 1);
PRINT rc

-- Check the optimizer actually uses the vector index (look for VECTOR INDEX in the plan):
EXPLAIN PLAN FOR
  SELECT chunk_id FROM kb_chunk
  ORDER BY VECTOR_DISTANCE(embedding, VECTOR_EMBEDDING(doc_model USING 'invoice problem' AS data), COSINE)
  FETCH APPROX FIRST 3 ROWS ONLY;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
