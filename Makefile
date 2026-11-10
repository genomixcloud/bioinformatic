# Build GenHub tool images and push them to Docker Hub.
#
# Default values (can be overridden when running make)
DOCKER_IMAGE ?=
DOCKER_TAG ?= latest
DOCKER_DIR ?= tools/$(DOCKER_IMAGE)
# --no-cache	Do not use cache when building the image
CACHE ?=
# Build arguments, either as KEY=VALUE pairs ("A=1 B=2") or as raw docker
# options ("--build-arg A=1 --build-arg B=2"). If any word starts with "--",
# BUILD_ARG is passed to docker build as it is.
BUILD_ARG ?=
PLATFORM ?= linux/amd64

# Docker Hub namespace (user or organisation) the image is pushed to.
# Assumes you are already logged in with `docker login`.
DOCKERHUB_ACCOUNT ?= genomixcloud

BUILD_ARGS = $(if $(filter --%,$(BUILD_ARG)),$(BUILD_ARG),$(addprefix --build-arg ,$(BUILD_ARG)))
REMOTE_IMAGE = $(DOCKERHUB_ACCOUNT)/$(DOCKER_IMAGE):$(DOCKER_TAG)
TOOLS = $(sort $(patsubst tools/%/Dockerfile,%,$(wildcard tools/*/Dockerfile)))

.PHONY: help
help:
	@echo ""
	@echo "Usage:"
	@echo "  make <target> DOCKER_IMAGE=<TOOL> [DOCKER_TAG=<tag>] [DOCKERHUB_ACCOUNT=<account>]"
	@echo ""
	@echo "Targets:"
	@echo "  list       List the tools that have a Dockerfile under tools/"
	@echo "  build      Build docker image <TOOL>:<tag> from tools/<TOOL>"
	@echo "  push       Tag and push the image to Docker Hub as <account>/<TOOL>:<tag>"
	@echo "  test       Run tools/<TOOL>/test.sh on the image, if the tool has one"
	@echo "  build-all  Build the image, test it and push it to Docker Hub"
	@echo "  clean      Remove the local and the Docker Hub-tagged image"
	@echo ""
	@echo "IMPORTANT:"
	@echo "  <push> target requires execute <build> first"
	@echo "  <push> assumes you are already logged in to Docker Hub (docker login)"
	@echo "  The repository is created on Docker Hub on first push if the account allows it"
	@echo ""
	@echo "Optional variables:"
	@echo "  DOCKER_TAG:        <tag>                    Default: $(DOCKER_TAG)"
	@echo "  DOCKER_DIR:        <build context>          Default: tools/<TOOL>"
	@echo "  DOCKERHUB_ACCOUNT: <user or organisation>   Default: genomixcloud"
	@echo "  CACHE:             --no-cache"
	@echo "  BUILD_ARG:         'KEY=VALUE ...' or '--build-arg KEY=VALUE ...'"
	@echo "  PLATFORM:          Default: $(PLATFORM)"
	@echo ""
	@echo "Examples:"
	@echo "  make build-all DOCKER_IMAGE=roary DOCKER_TAG=3.13.0"
	@echo "  make push DOCKER_IMAGE=bakta DOCKERHUB_ACCOUNT=myuser"
	@echo ""

.PHONY: list
list:
	@printf '%s\n' $(TOOLS)

.PHONY: check
check:
	@test -n "$(DOCKER_IMAGE)" || { echo "ERROR: set DOCKER_IMAGE=<TOOL> (see 'make list')"; exit 1; }
	@test -f "$(DOCKER_DIR)/Dockerfile" || { echo "ERROR: no Dockerfile in $(DOCKER_DIR)"; exit 1; }

# Build the Docker image NOT Multiplatform just linux/amd64
.PHONY: build
build: check
	docker build $(BUILD_ARGS) $(CACHE) --platform=$(PLATFORM) -t $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_DIR)

# Smoke test: runs tools/<TOOL>/test.sh <image:tag> when the tool has one
.PHONY: test
test: check
	@if [ -x "$(DOCKER_DIR)/test.sh" ]; then "$(DOCKER_DIR)/test.sh" $(DOCKER_IMAGE):$(DOCKER_TAG); \
	else echo "No $(DOCKER_DIR)/test.sh, skipping smoke test"; fi

# Push the image to Docker Hub
.PHONY: push
push: check
	@docker image inspect $(DOCKER_IMAGE):$(DOCKER_TAG) >/dev/null 2>&1 || \
		{ echo "ERROR: local image $(DOCKER_IMAGE):$(DOCKER_TAG) not found, run 'make build' first"; exit 1; }
	@echo "Tagging Docker image for Docker Hub..."
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(REMOTE_IMAGE)
	@echo "Pushing Docker image to Docker Hub..."
	docker push $(REMOTE_IMAGE)
	@echo "Push complete! $(REMOTE_IMAGE)"

.PHONY: build-all
build-all: build test push

# Remove local images (does not touch Docker Hub)
.PHONY: clean
clean: check
	-docker rmi $(REMOTE_IMAGE) $(DOCKER_IMAGE):$(DOCKER_TAG)
