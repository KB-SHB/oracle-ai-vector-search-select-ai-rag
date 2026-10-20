# Consultant playbook: how to talk about this project

## 90-second pitch
"I built a support-intelligence assistant on Oracle AI Database 26ai. Tickets and knowledge-base content live in one
schema; articles are chunked and embedded inside the database with an ONNX model, indexed with HNSW, and retrieved with
hybrid SQL. Answers are generated through Select AI on OCI Generative AI with grounding and citations, every answer is audited,
and I measure retrieval quality with Recall@k and MRR so changes can be justified with numbers. My background is SQL and PL/SQL,
so I deliberately pushed as much logic as sensible into the database and used OCI only where it added value."

## Discovery questions to ask a real customer
1. Which decisions or processes should the AI improve, and how will success be measured (time saved, deflection rate, accuracy)?
2. What data is involved, where does it live, and who owns it? Any personal, financial, or regulated data?
3. May data leave the tenancy or region? Which LLM providers are approved?
4. Who may see which documents, and must answers respect those permissions?
5. What is the acceptable error rate and what happens when the answer is wrong?
6. Expected volume, latency target, and budget per query?
7. Who operates it after go-live (DBAs, developers, a vendor)?

## Security and governance checklist
- Least-privilege schema user; Select AI `object_list` limited; no DDL/DML from AI.
- Secrets via resource principal or vault, not scripts. Private endpoint and network ACLs in production.
- Row-level access (VPD / Real Application Security) applied **before** retrieval so users cannot retrieve forbidden chunks.
- Audit table plus database auditing; retention policy.
- Prompt-injection awareness: retrieved text is untrusted input.
- Data masking / Data Safe for any real data used in testing.

## Cost levers
Embeddings in-DB (no per-token cost) vs API; smaller `k`; caching frequent answers; smaller model for easy questions; ECPU autoscaling limits; schedule re-embedding only for changed rows.

## Likely interview questions and strong answers
- **Why not a dedicated vector database?** Converged data: one security model, transactions, joins, backup/HA; trade-off is specialised features and team familiarity.
- **HNSW vs IVF?** HNSW: better speed/recall, in-memory graph; IVF: less memory, good for larger sets; always measure Recall with target accuracy.
- **How do you reduce hallucinations?** Retrieve-then-generate, strict instructions, citations, refusal path, evaluation set, human escalation, audit.
- **How do you know it works?** Golden questions, Recall@k/MRR for retrieval, rubric or human review for answers, regression run after each change.
- **What would you change at 10 million chunks?** IVF or partitioned approach, Exadata/vector memory sizing, batch embedding, hybrid ranking, monitoring.
- **What did you struggle with?** Use your real notes from `LESSONS_LEARNED.md`. Honest, specific answers beat polished ones.

## Portfolio hygiene
Public GitHub repo, clear README with screenshots and your real metrics, 3-minute screen-recorded demo, no secrets or real data committed,
and a short blog post or LinkedIn write-up explaining one decision and one mistake.
