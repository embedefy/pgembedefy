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
INSERT INTO products (name)
VALUES
    ('Bacon'),
    ('Bagel'),
    ('Coffee'),
    ('Croissant'),
    ('Oatmeal'),
    ('Omelette'),
    ('Orange juice'),
    ('Pancake mix'),
    ('Tea'),
    ('Cream cheese'),
    ('Brocoli'),
    ('Chicken wings'),
    ('Eggplant'),
    ('Hummus'),
    ('Meatballs'),
    ('Mixed salad'),
    ('Noodles'),
    ('Pasta'),
    ('Soda'),
    ('Sparkling water'),
    ('Beef steak'),
    ('Caesar salad'),
    ('Green tea'),
    ('Lamb chops'),
    ('Pizza sauce'),
    ('Red wine'),
    ('Rice'),
    ('Salmon fillet'),
    ('Sweet potatoes'),
    ('Tiramisu');
```

Create the embeddings table:

```sql
SELECT embedefy_embeddings_table_create('products', ARRAY['id'], 'bge-small-en-v1.5');

-- It may take some time, depending on the number of items and the speed of your internet connection.
-- You can stop it any time by pressing Ctrl+C. If it fails for some reason, run it again.
SELECT embedefy_embeddings_table_process('products', 'name', 'bge-small-en-v1.5');
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

> Make sure you have [pgvector](https://github.com/pgvector/pgvector) installed.

```shell
# macOS dependencies
# Note that based on your system you might need to install other dependencies.
# See dependencies for asdf at https://asdf-vm.com/guide/getting-started.html#_1-install-dependencies
brew install asdf icu4c json-c

# For Postgres 16 you need to export icu4c compiler flags
# Run `brew info icu4c` and export the compiler flags
export LDFLAGS="-L/opt/homebrew/opt/icu4c/lib"
export CPPFLAGS="-I/opt/homebrew/opt/icu4c/include"

# Install PostgreSQL
asdf plugin-add postgres
asdf install postgres 16.1
# Set the version to use in the current shell session
# You can also set it locally by running `asdf local postgres 16.1` or globally by running `asdf global postgres 16.1`
asdf shell postgres 16.1
# Check the version
postgres --version

# Build
cd src/
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
