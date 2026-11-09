COMPOSE := docker compose --project-directory atlantis

.PHONY: generate check app up down e2e

generate: ## Write the git-ignored generated files and atlantis.yaml locally
	terramate generate
	terramate-atlantis-config generate

check: ## What CI runs
	terramate generate
	terramate-atlantis-config generate
	terramate-atlantis-config validate atlantis.yaml

app: ## Create the GitHub App that Atlantis runs as (once)
	atlantis/create-github-app.py

up: ## Start Atlantis and the tunnel GitHub reaches it through
	atlantis/up.sh

e2e: ## Open the example pull requests and check Atlantis' answers
	atlantis/e2e.sh

down: ## Stop Atlantis and the tunnel
	$(COMPOSE) down
