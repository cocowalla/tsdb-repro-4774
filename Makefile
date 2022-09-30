.ONESHELL:
SHELL         := bash
.SHELLFLAGS   := -eu -o pipefail -c
.DEFAULT_GOAL := help

all: build push

build: convert-line-endings ## Build and tag the TSDB Repro image
	@docker build --tag tsdb-repro:latest .

rebuild: convert-line-endings rebuild-image ## Rebuild and tag the TSDB Repro image
	@docker build --no-cache --tag tsdb-repro:latest .

run: ## Run a container with the TSDB Repro image
	@docker run -it --rm \
		--name tsdb-repro \
		--hostname=tsdb-repro \
		--env POSTGRES_PASSWORD="Password1" \
		-p 127.0.0.1:5432:5432 \
		tsdb-repro:latest

stop: ## Stop the TSDB Repro container, if it's running
	@docker stop tsdb-repro 2>/dev/null || true

convert-line-endings: ## Convert line endings to LF in content files
	@echo -n "Converting line endings..."; \
		shopt -s globstar; \
		sed -i "s/\r//g" files/config/*.*; \
		sed -i "s/\r//g" files/**/*.sql; \
		sed -i "s/\r//g" files/**/*.sh; \
		sed -i "s/\r//g" Dockerfile; \
		echo " OK"

help: ## Prints this help message
	@echo "Available targets:"
	grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' Makefile | sort | awk "BEGIN {FS = \":.*?## \"}; {printf \"$$(tput setaf 3)%-30s$$(tput sgr0) %s\n\", \$$1, \$$2}"
