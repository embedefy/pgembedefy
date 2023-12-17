\echo Use "CREATE EXTENSION embedefy" to load this file. \quit

-- functions

-- embedefy_embeddings returns embeddings for the given model and input.
CREATE OR REPLACE FUNCTION embedefy_embeddings(model text, input text) RETURNS text
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

-- embedefy_embeddings_table_create creates a table for storing embeddings.
CREATE OR REPLACE FUNCTION embedefy_embeddings_table_create(
  input_table text,
  input_primary_keys text[],
  input_model text,
  input_embeddings_table text
)
RETURNS text AS $$
DECLARE
  embeddings_table text;
  embedding_dims int;
  pk_definition text := '';
  pk_column_type text;
  pk_i int;
BEGIN
  -- Check the embeddings table name
  IF input_embeddings_table IS NULL OR input_embeddings_table = '' THEN
    -- Replace anything but letters, numbers, and underscores and then make it all lower case
    embeddings_table := lower(regexp_replace(format('embedefy_%s', input_table), '[^a-zA-Z0-9_]', '_', 'g'));
  ELSE
    embeddings_table := input_embeddings_table;
  END IF;

  -- Check if the embeddings table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables t WHERE t.table_name = embeddings_table) THEN
    RAISE EXCEPTION 'table "%" already exists', embeddings_table;
  END IF;

  -- Check if the source table exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables t WHERE t.table_name = input_table) THEN
    RAISE EXCEPTION 'table "%" does not exist', input_table;
  END IF;

  -- Check the source table primary keys and get the column type for each column
  FOR pk_i IN 1..array_upper(input_primary_keys, 1) LOOP
    -- Fetch type for the current column
    SELECT c.data_type INTO pk_column_type 
    FROM information_schema.columns c 
    WHERE c.table_name = input_table AND c.column_name = input_primary_keys[pk_i];

    -- Check if column type was found
    IF pk_column_type IS NULL THEN
      RAISE EXCEPTION 'could not determine the type of the primary key column "%" in table "%"', input_primary_keys[pk_i], input_table;
    END IF;

    -- Append to primary key definition
    IF pk_i > 1 THEN
      pk_definition := pk_definition || ', ';
    END IF;
    pk_definition := pk_definition || input_primary_keys[pk_i] || ' ' || pk_column_type;
  END LOOP;
  -- RAISE NOTICE 'pk_definition: %', pk_definition;

  -- Get the embedding dimensions (makes a request to the Embedefy API)
  SELECT vector_dims(embedefy_embeddings(input_model, 'test')::vector) INTO embedding_dims;

  -- Create the embeddings table
  EXECUTE format('
    CREATE TABLE IF NOT EXISTS %I (
      %s,
      table_name text NOT NULL DEFAULT %L,
      column_name text NOT NULL,
      model_name text NOT NULL,
      embedding vector(%s) NOT NULL,
      PRIMARY KEY (%s),
      FOREIGN KEY (%s) REFERENCES %I(%s) ON DELETE CASCADE
    );
  ', embeddings_table, pk_definition, input_table, embedding_dims, array_to_string(input_primary_keys, ', '), array_to_string(input_primary_keys, ', '), input_table, array_to_string(input_primary_keys, ', '));

  EXECUTE format('COMMENT ON TABLE %I IS %L', embeddings_table, format('Embeddings for %I', input_table));

  -- Creating necessary indexes
  EXECUTE format('CREATE INDEX IF NOT EXISTS %I_table_name_idx ON %I (table_name);', embeddings_table, embeddings_table);
  EXECUTE format('CREATE INDEX IF NOT EXISTS %I_column_name_idx ON %I (column_name);', embeddings_table, embeddings_table);
  EXECUTE format('CREATE INDEX IF NOT EXISTS %I_model_name_idx ON %I (model_name);', embeddings_table, embeddings_table);
  EXECUTE format('CREATE INDEX IF NOT EXISTS %I_embedding_idx ON %I USING hnsw (embedding vector_cosine_ops);', embeddings_table, embeddings_table);

  RETURN format('table %I created', embeddings_table);
END;
$$ LANGUAGE plpgsql;

-- embedefy_embeddings_table_drop drops the table created by the embedefy_embeddings_table_create function.
CREATE OR REPLACE FUNCTION embedefy_embeddings_table_drop(input_table text)
RETURNS text AS $$
DECLARE
  expected_columns text[] := ARRAY['table_name', 'column_name', 'model_name', 'embedding'];
  column_count int;
BEGIN
  -- Check if the table exists and has the specific columns
  SELECT COUNT(*) INTO column_count
  FROM information_schema.columns
  WHERE table_name = input_table
    AND column_name IN (SELECT UNNEST(expected_columns));

  -- Drop the table if it exists and has the specific columns
  IF column_count = array_length(expected_columns, 1) THEN
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', input_table);
    RETURN format('table %I dropped', input_table);
  ELSE
    RAISE EXCEPTION 'table % does not exist or is not an embeddings table', input_table;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- embedefy_embeddings_table_process processes the embeddings for a table.
CREATE OR REPLACE FUNCTION embedefy_embeddings_table_process(
  input_table text,
  input_column text,
  input_model text,
  input_embeddings_table text
)
RETURNS text AS $$
DECLARE
  embeddings_table text;
  fk_info record;
  select_query text;
  select_query_columns text[];
  select_query_join_condition text[];
  select_query_where_condition text[];
  insert_query text;
  insert_query_columns text[];
BEGIN
  -- Check the embeddings table name
  IF input_embeddings_table IS NULL OR input_embeddings_table = '' THEN
    -- Replace anything but letters, numbers, and underscores and then make it all lower case
    embeddings_table := lower(regexp_replace(format('embedefy_%s', input_table), '[^a-zA-Z0-9_]', '_', 'g'));
  ELSE
    embeddings_table := input_embeddings_table;
  END IF;

  -- Check if the embeddings table exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables t WHERE t.table_name = embeddings_table) THEN
    RAISE EXCEPTION 'table "%" does not exist', embeddings_table;
  END IF;

  -- Check if the source table exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables t WHERE t.table_name = input_table) THEN
    RAISE EXCEPTION 'table "%" does not exist', input_table;
  END IF;

  -- Check if the source table columns exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns c WHERE c.table_name = input_table AND c.column_name = input_column) THEN
    RAISE EXCEPTION 'table "%" does not have column "%"', input_table, input_column;
  END IF;

  -- Retrieve foreign key information from embeddings_table and input_table.
  -- Note that the foreign keys are determined by the input_table primary keys in the embedefy_embeddings_table_create function.
  FOR fk_info IN
    SELECT DISTINCT
      kcu.table_name AS embeddings_table,
      kcu.column_name AS embeddings_column,
      ccu.table_name AS referenced_table,
      ccu.column_name AS referenced_column
    FROM 
      information_schema.table_constraints AS tc 
    JOIN 
      information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
    JOIN 
      information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
    WHERE 
      tc.constraint_type = 'FOREIGN KEY' 
      AND tc.table_name = embeddings_table
      AND ccu.table_name = input_table
      AND kcu.column_name = ccu.column_name -- enforce direct mapping / avoid cross mapping
  LOOP
    select_query_columns := array_append(select_query_columns, format('%I.%I', fk_info.referenced_table, fk_info.referenced_column));
    select_query_join_condition := array_append(select_query_join_condition, format('%I.%I = %I.%I', fk_info.embeddings_table, fk_info.embeddings_column, fk_info.referenced_table, fk_info.referenced_column));
    select_query_where_condition := array_append(select_query_where_condition, format('%I.%I IS NULL', fk_info.embeddings_table, fk_info.embeddings_column));
    insert_query_columns := array_append(insert_query_columns, format('%I', fk_info.embeddings_column));
  END LOOP;

  -- Check the queries
  IF 
    array_length(select_query_columns, 1) = 0 
    OR 
    array_length(select_query_join_condition, 1) = 0 
    OR 
    array_length(select_query_where_condition, 1) = 0 
    OR
    array_length(insert_query_columns, 1) = 0
  THEN
    RAISE EXCEPTION 'failed to construct the queries for "%" and "%" tables', embeddings_table, input_table;
  END IF;

  -- Prepare the query for selecting the records to be processed
  select_query := format('
    SELECT
      %s,
      %L as table_name,
      %L as column_name,
      %L as model_name,
      embedefy_embeddings(%L, %I.%I)::vector as embedding
    FROM 
      %I 
    LEFT JOIN %I ON %s WHERE (%s)
  ',
    array_to_string(select_query_columns, ', '),
    input_table,
    input_column,
    input_model,
    input_model,
    input_table,
    input_column,
    input_table,
    embeddings_table,
    array_to_string(select_query_join_condition, ' AND '),
    array_to_string(select_query_where_condition, ' OR ')
  );
  -- RAISE NOTICE 'select_query: %', select_query;

  -- Prepare the query for inserting the embeddings
  insert_query := format('
    INSERT INTO 
      %I 
    (%s, table_name, column_name, model_name, embedding) 
      %s;
    ',
    embeddings_table,
    array_to_string(insert_query_columns, ', '),
    select_query
  );
  -- RAISE NOTICE 'insert_query: %', insert_query;

  -- Execute the query
  EXECUTE insert_query;

  RETURN format('table %I processed', embeddings_table);
END;
$$ LANGUAGE plpgsql;
