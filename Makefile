CURRENT_WORKING_DIR=$(shell pwd)

init:
	brew install k3d

cluster:
	k3d cluster create kafka-gitops --servers 4

destroy:
	k3d cluster delete kafka-gitops

install-flux:
	./scripts/flux-init.sh

test-%:
	mkdir -p _test
	kustomize build environments/$* > _test/$*.yaml
	@echo
	@echo The output can be found at _test/$*.yaml
