# Lessons learned (fill in as you go)

- ORA-12899: the status column was too short for IN_PROGRESS. Found it by reading the Script Output tab, widened the column.
- ORA-00904: VECTOR_CHUNKS has no chunk_id column. Used ROW_NUMBER() instead.
- ORA-22849: COUNT() does not work on a VECTOR column. Counted with WHERE embedding IS NOT NULL.
- Retrieval baseline scored 1.0 on 10 questions. The set is too small to prove much.
“ORA-14551: a function called from SELECT cannot do DML. Moved the audit insert into an autonomous transaction procedure.”
