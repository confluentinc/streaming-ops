.PHONY: *

HELP_TAB_WIDTH = 25

.DEFAULT_GOAL := help

SHELL=/bin/bash -o pipefail

IMAGE_NAME := cnfldemos/orders-service
IMAGE_REPOSITORY ?=
VERSION := $(shell ./gradlew properties --no-daemon --console=plain -q | grep "^version:" | awk '{printf $$2}')

SHA    := $$(git log -1 --pretty=%h)
LATEST := ${NAME}:latest

IMAGE_FULL_NAME := $(IMAGE_REPOSITORY)$(IMAGE_NAME):$(VERSION)
IMAGE_SHA_NAME  := $(IMAGE_REPOSITORY)$(IMAGE_NAME):sha-$(SHA)

check-dependency = $(if $(shell command -v $(1)),,$(error Make sure $(1) is installed))

version:
	@printf "%s\n" $(VERSION)
	@printf "%s\n" $(IMAGE_FULL_NAME)
	@printf "%s\n" $(IMAGE_SHA_NAME)

clean:
	@./gradlew clean

test: clean
	@./gradlew test

build: test
	@./gradlew bootJar

package: build
	@docker build -t $(IMAGE_FULL_NAME) .
	@docker tag $(IMAGE_FULL_NAME) $(IMAGE_SHA_NAME)

publish: package
	@docker push $(IMAGE_FULL_NAME)
	@docker push $(IMAGE_SHA_NAME)

help:
	@$(foreach m,$(MAKEFILE_LIST),grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(m) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-$(HELP_TAB_WIDTH)s\033[0m %s\n", $$1, $$2}';)

