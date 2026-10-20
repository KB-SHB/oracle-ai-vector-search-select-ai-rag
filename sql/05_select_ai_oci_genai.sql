-- Run as SUPPORT_AI.  Connects the database to OCI Generative AI via Select AI.
-- Prerequisite: an OCI compartment with Generative AI access in a supported region
-- (see docs/OCI_SETUP.md).  Two auth options:
--   (1) Resource principal (preferred on Autonomous DB, no keys stored):
--         ADMIN:  EXEC DBMS_CLOUD_ADMIN.ENABLE_RESOURCE_PRINCIPAL(username => 'SUPPORT_AI');
--         plus an OCI IAM dynamic-group + policy allowing the ADB to use generative-ai-family.
--   (2) API-key credential (below), simpler for a first run.

BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'OCI_GENAI_CRED',
    user_ocid       => '<ocid1.user...>',
    tenancy_ocid    => '<ocid1.tenancy...>',
    private_key     => '<private key contents, no header/footer lines>',
    fingerprint     => '<api key fingerprint>');
END;
/

-- Profile A: RAG answer generation (used by kb_search_pkg.answer)
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'SUPPORT_GENAI',
    attributes   => '{
      "provider": "oci",
      "credential_name": "OCI_GENAI_CRED",
      "oci_compartment_id": "<ocid1.compartment...>"
    }');
END;
/

-- Profile B: Natural-language-to-SQL over the structured ticket data.
-- Least privilege: the LLM only sees metadata of the listed objects, never row data.
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'SUPPORT_NL2SQL',
    attributes   => '{
      "provider": "oci",
      "credential_name": "OCI_GENAI_CRED",
      "oci_compartment_id": "<ocid1.compartment...>",
      "object_list": [
        {"owner": "SUPPORT_AI", "name": "TICKET"},
        {"owner": "SUPPORT_AI", "name": "PRODUCT"},
        {"owner": "SUPPORT_AI", "name": "KB_ARTICLE"}
      ]
    }');
END;
/

COMMENT ON TABLE ticket  IS 'Customer support tickets. severity: LOW/MEDIUM/HIGH/CRITICAL. status: OPEN/IN_PROGRESS/RESOLVED';
COMMENT ON COLUMN ticket.created_at IS 'When the ticket was opened';
COMMENT ON COLUMN ticket.resolved_article_id IS 'Knowledge base article used to resolve the ticket';

-- ---- Demo 1: natural language to SQL ----------------------------------------------------
EXEC DBMS_CLOUD_AI.SET_PROFILE('SUPPORT_NL2SQL');

SELECT AI showsql how many open critical tickets are there for each product;
SELECT AI how many open critical tickets are there for each product;
SELECT AI narrate which knowledge base article resolved the most tickets;

-- ---- Demo 2: full RAG over the knowledge base -------------------------------------------
SELECT kb_search_pkg.answer('A client was charged twice, what should I do?') AS answer FROM dual;
SELECT kb_search_pkg.answer('How do I reset the CEO password?')              AS answer FROM dual;  -- should say "I don't know"

-- ---- Demo 3: hybrid query: semantic search + relational facts in one statement -----------
-- "Which unresolved tickets look like known issues, and which article would fix them?"
SELECT t.ticket_id, t.severity, t.subject, a.title AS suggested_article
FROM   ticket t
JOIN   kb_article a
  ON   a.article_id = (SELECT c.article_id
                       FROM   kb_chunk c
                       ORDER  BY VECTOR_DISTANCE(c.embedding,
                                   VECTOR_EMBEDDING(doc_model USING t.description AS data), COSINE)
                       FETCH FIRST 1 ROW ONLY)
WHERE  t.status <> 'RESOLVED' AND t.severity IN ('HIGH','CRITICAL')
FETCH FIRST 10 ROWS ONLY;
