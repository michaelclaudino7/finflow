.PHONY: help up down ingest ingest-full dbt-run dbt-test clean

PYTHON  := python3
DBT_IMG := ghcr.io/dbt-labs/dbt-postgres:1.7.latest
DBT_RUN := docker run --rm --network host \
	-v $(shell pwd)/dbt:/dbt \
	-e POSTGRES_HOST=localhost \
	-e POSTGRES_PORT=5432 \
	-e POSTGRES_USER=finflow \
	-e POSTGRES_PASSWORD=finflow123 \
	-e POSTGRES_DB=finflow \
	$(DBT_IMG)

# ─── Ajuda ────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  FinFlow — Comandos disponíveis"
	@echo "  ─────────────────────────────────────────────────────────"
	@echo "  Infraestrutura:"
	@echo "    make up           Sobe o PostgreSQL + Adminer via Docker"
	@echo "    make down         Para os containers"
	@echo ""
	@echo "  Pipeline:"
	@echo "    make ingest       Ingestão incremental (desde última data)"
	@echo "    make ingest-full  Ingestão completa (desde 2019)"
	@echo "    make dbt-run      Executa todos os modelos dbt"
	@echo "    make dbt-test     Roda os 57 testes do dbt"
	@echo "    make pipeline     Tudo: ingest + dbt-run + dbt-test"
	@echo ""
	@echo "  Dev:"
	@echo "    make clean        Remove arquivos temporários"
	@echo "  ─────────────────────────────────────────────────────────"

# ─── Infraestrutura ───────────────────────────────────────────────────────────
up:
	docker compose up -d
	@echo "✓ PostgreSQL em localhost:5432 | Adminer em http://localhost:8080"

down:
	docker compose down

# ─── Ingestão ────────────────────────────────────────────────────────────────
ingest:
	$(PYTHON) run_ingestion.py

ingest-full:
	$(PYTHON) run_ingestion.py --full

# ─── dbt (via Docker) ────────────────────────────────────────────────────────
dbt-run:
	$(DBT_RUN) run --profiles-dir /dbt --project-dir /dbt

dbt-test:
	$(DBT_RUN) test --profiles-dir /dbt --project-dir /dbt

# ─── Pipeline completa ───────────────────────────────────────────────────────
pipeline: ingest dbt-run dbt-test
	@echo ""
	@echo "  ✓ Pipeline FinFlow concluída com sucesso!"

# ─── Dev ─────────────────────────────────────────────────────────────────────
clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	rm -rf dbt/target dbt/dbt_packages dbt/logs
	@echo "✓ Limpeza concluída."
