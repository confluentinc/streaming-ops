.PHONY: *

HELP_TAB_WIDTH = 25

.DEFAULT_GOAL := help

SHELL=/bin/bash -o pipefail

IMAGE_NAME := cnfldemos/orders-service
IMAGE_REPOSITORY ?=
VERSION := $(shell ./gradlew properties --no-daemon --console=plain -q | grep "^version:" | awk '{printf $$2}')

IMAGE_FULL_NAME := $(IMAGE_REPOSITORY)$(IMAGE_NAME):$(VERSION)

check-dependency = $(if $(shell command -v $(1)),,$(error Make sure $(1) is installed))

clean:
	@./gradlew clean

test:
	@./gradlew test

build:
	@./gradlew bootJar

version:
	@printf "%s" $(VERSION)

package:
	@./gradlew bootBuildImage --imageName $(IMAGE_FULL_NAME)

publish: package
	@docker push $(IMAGE_FULL_NAME)

help:
	@$(foreach m,$(MAKEFILE_LIST),grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(m) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-$(HELP_TAB_WIDTH)s\033[0m %s\n", $$1, $$2}';)

