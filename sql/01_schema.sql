-- Run as SUPPORT_AI
-- Relational + unstructured + vector data in ONE schema: the "converged database" story.

CREATE TABLE product (
  product_id NUMBER PRIMARY KEY,
  name       VARCHAR2(60) NOT NULL
);

CREATE TABLE kb_article (
  article_id NUMBER PRIMARY KEY,
  product_id NUMBER NOT NULL REFERENCES product,
  title      VARCHAR2(200) NOT NULL,
  body       CLOB NOT NULL,
  updated_at DATE DEFAULT SYSDATE
);

-- One row per text chunk; embedding is a native VECTOR (384 dims = all-MiniLM-L12-v2)
CREATE TABLE kb_chunk (
  chunk_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  article_id NUMBER NOT NULL REFERENCES kb_article ON DELETE CASCADE,
  chunk_seq  NUMBER NOT NULL,
  chunk_text CLOB NOT NULL,
  embedding  VECTOR(384, FLOAT32)
);
CREATE INDEX kb_chunk_article_ix ON kb_chunk(article_id);

CREATE TABLE ticket (
  ticket_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id          NUMBER NOT NULL REFERENCES product,
  severity            VARCHAR2(10) CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  status              VARCHAR2(10) CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED')),
  subject             VARCHAR2(200),
  description         VARCHAR2(2000),
  created_at          TIMESTAMP,
  resolved_article_id NUMBER REFERENCES kb_article
);

-- Evaluation: does retrieval actually find the right article?
CREATE TABLE golden_question (
  gq_id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  question            VARCHAR2(500) NOT NULL,
  expected_article_id NUMBER NOT NULL REFERENCES kb_article
);

CREATE TABLE eval_run (
  run_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_ts       TIMESTAMP DEFAULT SYSTIMESTAMP,
  embed_model  VARCHAR2(60),
  k            NUMBER,
  n_questions  NUMBER,
  recall_at_k  NUMBER(5,3),
  mrr          NUMBER(5,3),
  notes        VARCHAR2(400)
);

-- Governance: every generated answer is auditable
CREATE TABLE rag_audit (
  audit_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asked_at    TIMESTAMP DEFAULT SYSTIMESTAMP,
  asked_by    VARCHAR2(128) DEFAULT SYS_CONTEXT('USERENV','SESSION_USER'),
  question    VARCHAR2(1000),
  article_ids VARCHAR2(200),
  answer      CLOB,
  latency_ms  NUMBER
);
