# pgembedefy

PostgreSQL extension for [Embedefy](https://www.embedefy.com/docs/pgembedefy).

The Embedefy PostgreSQL Extension provides access to embeddings directly from your database,
without building and maintaining additional applications. Once the extension is installed,
you can query your database as you normally would, but with the benefits of embeddings.

To use embeddings in PostgreSQL, install the pgembedefy extension and select a table and column to process.
Once the table column is processed, you can query your database with natural language,
getting results based on the semantic understanding.

## Requirements

- [Docker](https://www.docker.com)
- [asdf](https://asdf-vm.com) (only for development)

## Usage

### Run everything in Docker

This option builds and runs everything in Docker and it is suitable for testing purposes.

```shell
# We set the access token before running the PostgreSQL server
# to avoid having to set it for every connection session.
export EMBEDEFY_ACCESS_TOKEN=<your access token>

# Run the PostgreSQL server in the background
docker compose --file scripts/docker/docker-compose.yaml up -d
# To stop it, run `docker compose --file scripts/docker/docker-compose.yaml down`

# Connect to the PostgreSQL server
docker compose --file scripts/docker/docker-compose.yaml exec postgres psql -U postgres
```

Get embeddings for a given text:

```sql
select embedefy_embeddings('all-minilm-l6-v2', 'hello there');
```

Let's create a table, insert some data, and then query it using embeddings:

```sql
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name text UNIQUE
);
INSERT INTO products (name) VALUES ('Bacon');
INSERT INTO products (name) VALUES ('Bagel');
INSERT INTO products (name) VALUES ('Coffee');
INSERT INTO products (name) VALUES ('Croissant');
INSERT INTO products (name) VALUES ('Oatmeal');
INSERT INTO products (name) VALUES ('Omelette');
INSERT INTO products (name) VALUES ('Orange juice');
INSERT INTO products (name) VALUES ('Pancake mix');
INSERT INTO products (name) VALUES ('Tea');
INSERT INTO products (name) VALUES ('Cream cheese');
INSERT INTO products (name) VALUES ('Brocoli');
INSERT INTO products (name) VALUES ('Chicken wings');
INSERT INTO products (name) VALUES ('Eggplant');
INSERT INTO products (name) VALUES ('Hummus');
INSERT INTO products (name) VALUES ('Meatballs');
INSERT INTO products (name) VALUES ('Mixed salad');
INSERT INTO products (name) VALUES ('Noodles');
INSERT INTO products (name) VALUES ('Pasta');
INSERT INTO products (name) VALUES ('Soda');
INSERT INTO products (name) VALUES ('Sparkling water');
INSERT INTO products (name) VALUES ('Beef steak');
INSERT INTO products (name) VALUES ('Caesar salad');
INSERT INTO products (name) VALUES ('Green tea');
INSERT INTO products (name) VALUES ('Lamb chops');
INSERT INTO products (name) VALUES ('Pizza sauce');
INSERT INTO products (name) VALUES ('Red wine');
INSERT INTO products (name) VALUES ('Rice');
INSERT INTO products (name) VALUES ('Salmon fillet');
INSERT INTO products (name) VALUES ('Sweet potatoes');
INSERT INTO products (name) VALUES ('Tiramisu');
```

Create the embeddings table:

```sql
SELECT embedefy_embeddings_table_create('products', ARRAY['id'], 'bge-small-en-v1.5', null);

-- It may take some time, depending on the number of items and the speed of your internet connection.
-- You can stop it any time by pressing Ctrl+C. If it fails for some reason, run it again.
SELECT embedefy_embeddings_table_process('products', 'name', 'bge-small-en-v1.5', null);
```

> Note that you can call the `embedefy_embeddings_table_process` function at any time (e.g., in a trigger) to
> process new items in a table. It will process only those items that do not yet have embeddings.

Query the table by cosine similarity:

```sql
SELECT p.name
FROM products p, embedefy_products ep
WHERE p.id = ep.id
ORDER BY 1 - ((SELECT embedefy_embeddings('bge-small-en-v1.5', 'looking for breakfast items')::vector(384)) <=> ep.embedding) DESC
LIMIT 5;
```

```sql
    name
-------------
 Pancake mix
 Omelette
 Oatmeal
 Noodles
 Bacon
```

```sql
SELECT p.name
FROM products p, embedefy_products ep
WHERE p.id = ep.id
ORDER BY 1 - ((SELECT embedefy_embeddings('bge-small-en-v1.5', 'shopping for dinner')::vector(384)) <=> ep.embedding) DESC
LIMIT 5;
```

```sql
     name
---------------
 Mixed salad
 Pasta
 Caesar salad
 Chicken wings
 Beef steak
```

```sql
SELECT p.name
FROM products p, embedefy_products ep
WHERE p.id = ep.id
ORDER BY 1 - ((SELECT embedefy_embeddings('bge-small-en-v1.5', 'want to buy some drinks')::vector(384)) <=> ep.embedding) DESC
LIMIT 5;
```

```sql
      name
-----------------
 Soda
 Tea
 Coffee
 Sparkling water
 Green tea
```

> Note that the results may change depending on the embedding model used.
> You need to find the model that works best for your dataset.

Besides cosine similarity, there are other vector operations. For more details,
see [pgvector](https://github.com/pgvector/pgvector?tab=readme-ov-file#vector-types).

## Development

This is options builds and runs everything locally and it is suitable for development purposes.

```shell
# macOS dependencies
# Note that based on your system you might need to install other dependencies.
# Postgres 16 requires icu4c
# brew install icu4c
# Run `brew info icu4c` and export the compiler flags
brew install json-c

# Install PostgreSQL
asdf plugin-add postgres
asdf install postgres 15.5

# Build
make
# Install
make install
# Uninstall
make uninstall
# Clean
make clean
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

Copyright (c) 2023 Cloakbase Inc. All rights reserved.  
For the full copyright and license information, please view the LICENSE.txt file.
