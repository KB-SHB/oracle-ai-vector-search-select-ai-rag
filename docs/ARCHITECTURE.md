# Architecture notes and design decisions

## Decisions (write these as short ADRs in interviews)

| Decision | Choice | Alternatives | Rationale |
|---|---|---|---|
| Vector store | Oracle AI Vector Search in the same DB | Separate vector DB | One security model, ACID, joins with relational data, fewer moving parts |
| Embeddings | In-DB ONNX (MiniLM, 384 dims) | OCI GenAI embedding model | No data egress, no per-call cost, lower latency; weaker on multilingual or long text |
| Chunking | `VECTOR_CHUNKS`, 100 words, 20 overlap, sentence split | Fixed char size | Preserves meaning across boundaries; tune with the eval harness |
| Index | HNSW (in-memory) | IVF, exact search | Best recall/latency at small-to-mid scale; needs vector memory pool. IVF when memory limited or very large |
| LLM | OCI Generative AI via Select AI | External provider | Stays inside OCI tenancy boundary; Select AI also supports other providers if required |
| Orchestration | PL/SQL package | Python service | Close to the data, transactional audit, reuse existing DBA/dev skills. Python would be right for complex agent flows |
| NL2SQL scope | Metadata-only `object_list` for 3 tables | Whole schema | Least privilege, better accuracy |

## Known limitations (state them, don't hide them)
- Synthetic data; real KBs have tables, images, PDFs, versioning, and access control.
- Filtering with joins may reduce what an ANN index can pre-filter; for strict filters measure recall.
- Select AI NL2SQL is read-oriented; always review generated SQL (`showsql`) before trusting results in production.
- LLM answers are non-deterministic; keep the audit table and the golden-question evaluation in CI.
- 10 articles is a toy. The method scales, but Recall@k on 10 documents proves little. Add a larger public corpus (e.g. product documentation) to make the numbers meaningful.

## Scaling path
Ingest documents from Object Storage with `DBMS_CLOUD`, convert with `DBMS_VECTOR_CHAIN.UTL_TO_TEXT`, schedule with `DBMS_SCHEDULER`,
re-embed only changed articles, monitor index freshness, add hybrid (keyword + vector) ranking, and add a re-ranker for the top results.
