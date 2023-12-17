\echo Use "DROP EXTENSION embedefy" to load this file. \quit

-- functions
-- For now lets play safe, not use CASCADE and let users to handle dependencies.
DROP FUNCTION IF EXISTS embedefy_embeddings;
DROP FUNCTION IF EXISTS embedefy_embeddings_table_create;
DROP FUNCTION IF EXISTS embedefy_embeddings_table_drop;
DROP FUNCTION IF EXISTS embedefy_embeddings_table_process;
