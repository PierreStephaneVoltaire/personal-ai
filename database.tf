resource "digitalocean_database_cluster" "postgres" {
  name       = "${var.project_name}-db"
  engine     = "pg"
  version    = "16"
  size       = "db-s-1vcpu-1gb"
  region     = var.region
  node_count = 1
}

resource "digitalocean_database_db" "personal_ai" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "personal-ai"
}

resource "digitalocean_database_db" "n8n" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "n8n"
}

# Note: pgvector extension needs to be enabled via SQL: "CREATE EXTENSION vector;"
# This can be done by connecting to the database after creation.
# Run: psql <connection_uri> -c "CREATE EXTENSION IF NOT EXISTS vector;"
# LibreChat uses MongoDB (deployed separately) instead of PostgreSQL
