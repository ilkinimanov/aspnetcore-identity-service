.PHONY: help build dev test prod up down logs shell clean clean-all rebuild test-results

# Variables
COMPOSE_DEV = docker compose -f docker-compose.dev.yml
COMPOSE_TEST = docker compose -f docker-compose.test.yml
COMPOSE_PROD = docker compose -f docker-compose.yml
IMAGE_DEV = identity-service:development
IMAGE_TEST = identity-service:test
IMAGE_PROD = identity-service:production
CONTAINER_DEV = identity-service-api-dev
CONTAINER_TEST = identity-service-test
CONTAINER_PROD = identity-service-api

# Default target
.DEFAULT_GOAL := help

##@ Help

help: ## Display this help message
	@echo "Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

##@ Development

dev: ## Start development service in watch mode
	$(COMPOSE_DEV) up --build

dev-build: ## Build development image
	$(COMPOSE_DEV) build

dev-up: ## Start development service (detached)
	$(COMPOSE_DEV) up -d --build

dev-down: ## Stop development service
	$(COMPOSE_DEV) down

dev-logs: ## View development service logs
	$(COMPOSE_DEV) logs -f

dev-shell: ## Open shell in development container
	$(COMPOSE_DEV) exec identity-service-api sh

dev-restart: ## Restart development service
	$(COMPOSE_DEV) restart

##@ Testing

test: ## Run all tests
	$(COMPOSE_TEST) up --build --abort-on-container-exit

test-build: ## Build test image
	$(COMPOSE_TEST) build

test-run: ## Run tests (without building)
	$(COMPOSE_TEST) up --abort-on-container-exit

test-shell: ## Open shell in test container
	$(COMPOSE_TEST) run --rm test-runner sh

test-results: ## Show test results directory
	@echo "Test results are in ./test-results/"
	@ls -la test-results/ 2>/dev/null || echo "No test results yet. Run 'make test' first."

##@ Production

prod: ## Start production service
	$(COMPOSE_PROD) up -d --build

prod-build: ## Build production image
	$(COMPOSE_PROD) build

prod-up: ## Start production service (detached)
	$(COMPOSE_PROD) up -d

prod-down: ## Stop production service
	$(COMPOSE_PROD) down

prod-logs: ## View production service logs
	$(COMPOSE_PROD) logs -f

prod-shell: ## Open shell in production container
	$(COMPOSE_PROD) exec identity-service-api sh

prod-restart: ## Restart production service
	$(COMPOSE_PROD) restart

prod-status: ## Check production service status
	$(COMPOSE_PROD) ps

##@ Docker Build

build-dev: ## Build development Docker image
	docker build --target development -t $(IMAGE_DEV) .

build-test: ## Build test Docker image
	docker build --target test -t $(IMAGE_TEST) .

build-prod: ## Build production Docker image
	docker build --target production -t $(IMAGE_PROD) .

build-all: ## Build all Docker images
	@echo "Building all images..."
	@$(MAKE) build-dev
	@$(MAKE) build-test
	@$(MAKE) build-prod
	@echo "All images built successfully!"

##@ Docker Management

images: ## List all identity-service images
	docker images | grep identity-service

ps: ## List running containers
	docker ps | grep identity-service

stop-all: ## Stop all identity-service containers
	@echo "Stopping all containers..."
	@docker stop $(CONTAINER_DEV) $(CONTAINER_TEST) $(CONTAINER_PROD) 2>/dev/null || true
	@echo "All containers stopped."

##@ Cleanup

clean: ## Remove stopped containers and unused images
	@echo "Cleaning up containers and images..."
	@docker-compose -f docker-compose.dev.yml down -v 2>/dev/null || true
	@docker-compose -f docker-compose.test.yml down -v 2>/dev/null || true
	@docker-compose -f docker-compose.yml down -v 2>/dev/null || true
	@docker system prune -f
	@echo "Cleanup complete."

clean-all: ## Remove all containers, images, volumes, and test results
	@echo "Removing all containers..."
	@docker-compose -f docker-compose.dev.yml down -v --rmi all 2>/dev/null || true
	@docker-compose -f docker-compose.test.yml down -v --rmi all 2>/dev/null || true
	@docker-compose -f docker-compose.yml down -v --rmi all 2>/dev/null || true
	@echo "Removing images..."
	@docker rmi $(IMAGE_DEV) $(IMAGE_TEST) $(IMAGE_PROD) 2>/dev/null || true
	@echo "Removing test results..."
	@rm -rf test-results/
	@echo "Removing build artifacts..."
	@find . -type d -name "bin" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "obj" -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleanup complete."

##@ Rebuild

rebuild-dev: ## Rebuild development image from scratch
	$(COMPOSE_DEV) build --no-cache
	$(COMPOSE_DEV) up -d

rebuild-prod: ## Rebuild production image from scratch
	$(COMPOSE_PROD) build --no-cache
	$(COMPOSE_PROD) up -d

rebuild-test: ## Rebuild test image from scratch
	$(COMPOSE_TEST) build --no-cache

##@ Utility

logs: ## View logs (defaults to dev, use LOGS=prod or LOGS=test for others)
	@if [ "$(LOGS)" = "prod" ]; then \
		$(COMPOSE_PROD) logs -f; \
	elif [ "$(LOGS)" = "test" ]; then \
		$(COMPOSE_TEST) logs -f; \
	else \
		$(COMPOSE_DEV) logs -f; \
	fi

shell: ## Open shell (defaults to dev, use SHELL=prod or SHELL=test for others)
	@if [ "$(SHELL)" = "prod" ]; then \
		$(COMPOSE_PROD) exec identity-service-api sh; \
	elif [ "$(SHELL)" = "test" ]; then \
		$(COMPOSE_TEST) run --rm test-runner sh; \
	else \
		$(COMPOSE_DEV) exec identity-service-api sh; \
	fi

status: ## Show status of all services
	@echo "=== Development ==="
	@$(COMPOSE_DEV) ps 2>/dev/null || echo "Not running"
	@echo ""
	@echo "=== Production ==="
	@$(COMPOSE_PROD) ps 2>/dev/null || echo "Not running"
	@echo ""
	@echo "=== Test ==="
	@$(COMPOSE_TEST) ps 2>/dev/null || echo "Not running"

version: ## Show Docker and Docker Compose versions
	@echo "Docker version:"
	@docker --version
	@echo ""
	@echo "Docker Compose version:"
	@docker-compose --version
