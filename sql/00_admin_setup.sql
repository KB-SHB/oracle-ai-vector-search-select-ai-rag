-- Run as ADMIN on Autonomous AI Database (26ai/23ai). Always Free tier is enough.
-- Usage: @00_admin_setup.sql
DEFINE app_pwd = 'ChangeMe_2026#Strong'

CREATE USER support_ai IDENTIFIED BY "&app_pwd" QUOTA UNLIMITED ON data;
GRANT DB_DEVELOPER_ROLE TO support_ai;
GRANT CREATE MINING MODEL TO support_ai;          -- needed to load ONNX embedding models
GRANT EXECUTE ON DBMS_CLOUD     TO support_ai;
GRANT EXECUTE ON DBMS_CLOUD_AI  TO support_ai;    -- Select AI
GRANT EXECUTE ON DBMS_VECTOR    TO support_ai;
GRANT READ, WRITE ON DIRECTORY DATA_PUMP_DIR TO support_ai;  -- staging area for the ONNX model file

-- Allow outbound calls to OCI Generative AI endpoints
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => '*.oraclecloud.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
                        principal_name => 'SUPPORT_AI',
                        principal_type => xs_acl.ptype_db));
END;
/
