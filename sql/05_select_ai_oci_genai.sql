-- Run as SUPPORT_AI.  Connects the database to OCI Generative AI via Select AI.
-- DO NOT COMMIT A FILLED-IN COPY OF THIS FILE. Keep the <placeholders> in the repo.
-- Prerequisites: Generative AI available in your region (check the OCI Playground), an API key for your
-- user, and your tenancy/compartment OCID. Costs may apply to Generative AI calls.
SET DEFINE OFF

-- Optional clean-up when re-running
BEGIN DBMS_CLOUD_AI.DROP_PROFILE('SUPPORT_GENAI',  force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN DBMS_CLOUD_AI.DROP_PROFILE('SUPPORT_NL2SQL', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN DBMS_CLOUD.DROP_CREDENTIAL('OCI_GENAI_CRED');                EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- The private key goes in WITHOUT the BEGIN/END lines, on one line. The fingerprint must belong to that same key.
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'OCI_GENAI_CRED',
    user_ocid       => '<ocid1.user...>',
    tenancy_ocid    => '<ocid1.tenancy...>',
    private_key     => '<private key, one line, no header/footer>',
    fingerprint     => '<fingerprint of THIS key>');
END;
/

-- Quick credential test (expect HTTP status: 200). Run with SET SERVEROUTPUT ON.
-- DECLARE resp DBMS_CLOUD_TYPES.resp; BEGIN
--   resp := DBMS_CLOUD.SEND_REQUEST('OCI_GENAI_CRED',
--     'https://identity.<region>.oraclecloud.com/20160918/users/<ocid1.user...>', DBMS_CLOUD.METHOD_GET);
--   DBMS_OUTPUT.PUT_LINE('HTTP status: ' || DBMS_CLOUD.GET_RESPONSE_STATUS_CODE(resp)); END;
-- /

-- Profile A: RAG answer generation (used by kb_search_pkg.answer)
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'SUPPORT_GENAI',
    attributes   => '{"provider":"oci",
                      "credential_name":"OCI_GENAI_CRED",
                      "region":"<region, e.g. eu-frankfurt-1>",
                      "oci_compartment_id":"<ocid1.compartment or tenancy...>",
                      "model":"<chat model name from the OCI Playground>"}');
END;
/

-- Profile B: natural language to SQL. The model sees metadata of the listed objects only, not row data.
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'SUPPORT_NL2SQL',
    attributes   => '{"provider":"oci",
                      "credential_name":"OCI_GENAI_CRED",
                      "region":"<region, e.g. eu-frankfurt-1>",
                      "oci_compartment_id":"<ocid1.compartment or tenancy...>",
                      "model":"<chat model name from the OCI Playground>",
                      "comments":"true",
                      "object_list":[{"owner":"SUPPORT_AI","name":"TICKET"},
                                     {"owner":"SUPPORT_AI","name":"PRODUCT"},
                                     {"owner":"SUPPORT_AI","name":"KB_ARTICLE"}]}');
END;
/

-- Column comments improve NL2SQL accuracy
COMMENT ON TABLE  ticket IS 'Customer support tickets. severity is LOW, MEDIUM, HIGH or CRITICAL. status is OPEN, IN_PROGRESS or RESOLVED.';
COMMENT ON COLUMN ticket.created_at IS 'When the ticket was opened';
COMMENT ON COLUMN ticket.resolved_article_id IS 'Knowledge base article that resolved the ticket';
COMMENT ON TABLE  product IS 'Products sold by the company';
COMMENT ON TABLE  kb_article IS 'Knowledge base articles';

-- ---- Demo 1: greeting test ---------------------------------------------------------------
SELECT DBMS_CLOUD_AI.GENERATE(prompt => 'Say hello in one short sentence.',
                              profile_name => 'SUPPORT_GENAI', action => 'chat') AS reply FROM dual;

-- ---- Demo 2: RAG with citation, and the refusal case -------------------------------------
SELECT kb_search_pkg.answer('A client was charged twice, what should I do?') AS answer FROM dual;
SELECT kb_search_pkg.answer('How do I reset the CEO password?')              AS answer FROM dual;
SELECT audit_id, asked_at, question, article_ids, latency_ms FROM rag_audit ORDER BY audit_id;

-- ---- Demo 3: natural language to SQL: read the SQL, then verify the answer yourself --------
SELECT DBMS_CLOUD_AI.GENERATE(prompt => 'how many open critical tickets are there for each product',
                              profile_name => 'SUPPORT_NL2SQL', action => 'showsql') AS generated_sql FROM dual;
SELECT DBMS_CLOUD_AI.GENERATE(prompt => 'which knowledge base article resolved the most tickets',
                              profile_name => 'SUPPORT_NL2SQL', action => 'narrate') AS answer FROM dual;
-- Verification (articles 4 and 8 are tied at 16):
SELECT resolved_article_id, COUNT(*) AS tickets FROM ticket
WHERE resolved_article_id IS NOT NULL GROUP BY resolved_article_id ORDER BY tickets DESC;
