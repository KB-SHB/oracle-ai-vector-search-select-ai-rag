# OCI setup for someone coming from SQL/PL/SQL

You do not need to become an OCI expert for this project. You need five concepts.

| Concept | One-line meaning | Used here for |
|---|---|---|
| Tenancy / compartment | Your account and a folder for resources | Keep the project isolated and easy to delete |
| IAM policy | Who may do what to which resource | Letting the database call Generative AI |
| Autonomous AI Database | Managed Oracle DB (26ai features) | The whole solution |
| Object Storage + PAR | Bucket + a pre-authenticated link | Hosting the ONNX model file for loading |
| Generative AI service | Managed LLM endpoints | Answer generation behind Select AI |

## Steps

1. **Account.** Sign up for OCI Free Tier. Create a compartment `portfolio-ai`.
2. **Database.** Autonomous Database, workload *Transaction Processing* (or *Data Warehouse*), **Always Free**, version 26ai/23ai.
   Set the ADMIN password, keep default network access for the demo (restrict it for anything real; see Playbook).
3. **Bucket.** Create a private bucket, upload the ONNX embedding model, create a **pre-authenticated request** with read access and a short expiry. Paste that URL in `03_embeddings.sql`.
4. **Generative AI access.**
   - Confirm Generative AI is available in your region and note which models you can use.
   - Simplest path: create an API key for your user and use the key-based credential in `05_select_ai_oci_genai.sql`.
   - Better path (a good talking point): **resource principal**. Create a dynamic group matching your ADB's OCID and a policy such as
     `Allow dynamic-group <dg> to use generative-ai-family in compartment portfolio-ai`, then run
     `DBMS_CLOUD_ADMIN.ENABLE_RESOURCE_PRINCIPAL` for the schema. No keys stored in the database.
5. **Connect.** Use Database Actions (SQL worksheet) in the browser, or SQLcl with the wallet.
6. **Clean up / cost control.** Set a budget alert on the compartment. Always Free DB costs nothing; Generative AI calls may. Delete the PAR and any paid resources when done.

## Free-tier caveats to check yourself
Availability of Generative AI models, regions, and Always Free limits changes. Verify in the OCI console and docs before starting rather than trusting this file.
