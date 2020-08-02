CURRENT_WORKING_DIR=$(shell pwd)
WHO_AM_I=$(shell whoami)
TIMESTAMP=$(shell date)

KUBESEAL_VERSION = v0.12.1
YQ_VERSION = 3.3.2

kubeseal:
	wget https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-darwin-amd64
	sudo install -m 755 kubeseal-darwin-amd64 /usr/local/bin/kubeseal
	rm -f kubeseal-darwin-amd64

k3d:
	brew install k3d

jq:
	brew install jq

yq:
	wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_darwin_amd64
	sudo install -m 755 yq_darwin_amd64 /usr/local/bin/yq
	rm -f yq_darwin_amd64

kustomize:
	brew install kustomize

helm:
	brew install helm

install-deps: k3d kubeseal jq yq kustomize helm

cluster:
	k3d cluster create kafka-gitops --servers 4 --volume $(PWD)/.data:/var/lib/host --wait

destroy:
	k3d cluster delete kafka-gitops

install-bitnami-secret-controller:
	@kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.12.4/controller.yaml

wait-for-secret-controller:
	@./scripts/wait-for-secret-controller.sh

install-flux: 
	./scripts/flux-init.sh

FLUX_KEY=$(shell fluxctl identity --k8s-fwd-ns flux)

seal-%:
	./scripts/seal-secrets.sh $*

get-public-key:
ifndef ENV
	$(error ENV is not set.  Set it to indicate which environment to generate a key for)
endif
	kubeseal --fetch-cert > secrets/keys/$(ENV).crt

gh-deploy-key:
ifndef GH_TOKEN
	$(error GH_TOKEN is not set)
endif
	@KEY="$(FLUX_KEY)" NAME="kafka-devops-flux" ./scripts/create-deploy-key.sh

dev-demo:
ifndef SECRET_FILE
	$(error SECRET_FILE is not set)
endif
ifndef GH_TOKEN
	$(error GH_TOKEN is not set)
endif
	@-make --no-print-directory destroy
	@make --no-print-directory cluster
	@make --no-print-directory install-bitnami-secret-controller
	@make --no-print-directory wait-for-secret-controller
	@make --no-print-directory get-public-key ENV=dev
	@kubectl create secret generic kafka-secrets --namespace=default --from-file=kafka.properties=$(SECRET_FILE) --dry-run=client -o yaml > secrets/local-toseal/dev/default-kafka-secrets.yaml
	@make --no-print-directory seal-dev
	@git add secrets/sealed/dev/default-kafka-secrets.yaml
	@git commit -m "dev-demo: $(WHO_AM_I): $(TIMESTAMP)"
	@git push origin master
	@make --no-print-directory install-flux WAIT_FOR_DEPLOY=false
	@make --no-print-directory gh-deploy-key
	@fluxctl sync --k8s-fwd-ns flux

util:
	@kubectl run --tty -i --rm util --image=cnfldemos/util:0.0.4 --restart=Never --serviceaccount=in-cluster-sa --namespace=default

test-%:
	kustomize build environments/$* > .test/$*.yaml
	@echo
	@echo The output can be found at .test/$*.yaml

