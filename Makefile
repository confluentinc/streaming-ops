CURRENT_WORKING_DIR=$(shell pwd)
WHO_AM_I=$(shell whoami)
TIMESTAMP=$(shell date)

KUBESEAL_VERSION = v0.12.1
YQ_VERSION = 3.3.2

pad=$(printf '%0.1s' "-"{1..80})

define print-prompt =
printf "\e[96m➜ \e[0m"
endef

define print-header =
printf "\n%-50s\n" $1 | tr ' ~' '- '
endef

kubeseal:
	wget https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-darwin-amd64
	sudo install -m 755 kubeseal-darwin-amd64 /usr/local/bin/kubeseal
	rm -f kubeseal-darwin-amd64

yq:
	wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_darwin_amd64
	sudo install -m 755 yq_darwin_amd64 /usr/local/bin/yq
	rm -f yq_darwin_amd64

# Homebrew isn't great with installing specific version, so I'm using a direct git commit URL to pin to specific versions

kubectl:
	brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/9fec1d922fa734289eccaa495f13680587da8feb/Formula/kubernetes-cli.rb 

k3d:
	brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/5fb0385f36ad62ffb051eb3256dceec9f3dbfdd2/Formula/k3d.rb

jq:
	brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/81e08b0d9ae47a9968fabde84378faab1f67e557/Formula/jq.rb 

kustomize:
	brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/143e1af7c5a7fffc8e9ffa9be19396f24929a996/Formula/kustomize.rb 

helm:
	brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/6796c57c9ea504e74e26a32a14ab8c5758bf6750/Formula/helm.rb 

install-deps: kubectl k3d kubeseal jq yq kustomize helm

cluster:
	@$(call print-header,"creating new k3d cluster")
	@$(call print-prompt)
	k3d cluster create kafka-gitops --servers 4 --volume $(PWD)/.data:/var/lib/host --wait

destroy-cluster:
	@$(call print-header,"deleting k3d cluster")
	@$(call print-prompt)
	-(k3d cluster list | grep kafka-gitops) && k3d cluster delete kafka-gitops

install-bitnami-secret-controller:
	@$(call print-header,"Installing bitnami secret controller")
	@$(call print-prompt)
	kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.12.4/controller.yaml

wait-for-secret-controller:
	@$(call print-header,"Waiting for secret controller")
	@$(call print-prompt)
	./scripts/wait-for-secret-controller.sh

install-flux-%: 
	@$(call print-header,"Installing flux")
	@$(call print-prompt)
	ENVIRONMENT=$* ./scripts/flux-init.sh

FLUX_KEY=$(shell fluxctl identity --k8s-fwd-ns flux)

create-secrets-%:
ifndef KAFKA_SECRET_FILE 
	$(error KAFKA_SECRET_FILE is not set)
endif
	@$(call print-header,"Creating secrets")
	@$(call print-prompt)
	kubectl create secret generic kafka-secrets --namespace=default --from-file=kafka.properties=$(KAFKA_SECRET_FILE) --dry-run=client -o yaml > secrets/local-toseal/$*/default-kafka-secrets.yaml && echo "ready to seal: secrets/local-toseal/$*/default-kafka-secrets.yaml"
	@printf "\n"
	@$(call print-prompt)
	kubectl create secret generic connect-operator-secrets --namespace=default --from-env-file=./secrets/example-connect-operator-secrets.props --dry-run=client -o yaml > secrets/local-toseal/$*/default-connect-operator-secrets.yaml && echo "ready to seal: secrets/local-toseal/$*/default-connect-operator-secrets.yaml"
	@printf "\n"
	@$(call print-prompt)
	kubectl create secret generic ccloud-secrets --namespace=default --from-env-file=$(CCLOUD_SECRET_FILE) --dry-run=client -o yaml > secrets/local-toseal/$*/default-ccloud-secrets.yaml && echo "ready to seal: secrets/local-toseal/$*/default-ccloud-secrets.yaml"

seal-secrets-%:
	@$(call print-header,"Sealing secrets")
	@$(call print-prompt)
	./scripts/seal-secrets.sh $*

get-public-key-%:
	@$(call print-header,"Fetching bitnami controller public key")
	@$(call print-prompt)
	kubeseal --fetch-cert > secrets/keys/$*.crt

gh-deploy-key:
ifndef GH_TOKEN
	$(error GH_TOKEN is not set)
endif
	@$(call print-header,"deploying flux deploy key to GitHub")
	@$(call print-prompt)
	@KEY="$(FLUX_KEY)" NAME="kafka-devops-flux" ./scripts/create-deploy-key.sh

sync:
	@$(call print-header,"Flux sync")
	@$(call print-prompt)
	fluxctl sync --k8s-fwd-ns flux

demo-%:
ifndef KAFKA_SECRET_FILE
	$(error KAFKA_SECRET_FILE is not set)
endif
ifndef GH_TOKEN
	$(error GH_TOKEN is not set)
endif
	@-make --no-print-directory destroy-cluster
	@make --no-print-directory cluster
	@make --no-print-directory install-bitnami-secret-controller
	@make --no-print-directory wait-for-secret-controller
	@make --no-print-directory get-public-key-$*
	@make --no-print-directory create-secrets-$*
	@make --no-print-directory seal-secrets-$*
	@$(call print-header,"pushing new secrets to git repo")
	git add secrets/sealed/$*/.
	git commit -m "demo-$*: $(WHO_AM_I): $(TIMESTAMP)"'\n\n[ci skip]'
	git push origin master
	@make --no-print-directory install-flux-dev WAIT_FOR_DEPLOY=false
	@make --no-print-directory gh-deploy-key

prompt:
	@$(call print-header,"Launching util pod")
	@$(call print-prompt)
	kubectl run --tty -i --rm util --image=cnfldemos/util:0.0.5 --restart=Never --serviceaccount=in-cluster-sa --namespace=default

test-%:
	@$(call print-header,"Testing $* with Kustomize")
	@$(call print-prompt)
	kustomize build environments/$* > .test/$*.yaml
	@echo
	@echo The output can be found at .test/$*.yaml

