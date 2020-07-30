# kafka-devops

Simulated production environment running a streaming application targeting Apache Kafka on Confluent Cloud.
Applications and resources are managed by declarative infrastructure and GitOps.

# Tool prerequisites

## k3d
If you'd like to run the project on a local Docker based Kubernetes cluster

## Kustomize
Environments (dev, stg, prd, etc...) are created by using Kustomize style overlays

https://github.com/kubernetes-sigs/kustomize

## Helm 3
Used to install Flux into the cluster

https://helm.sh/docs/intro/install/

## Bitnami Sealed Secrets Kubeseal
The repository uses sealed secrets and the Bitnami controller for managing secret values. `kubeseal` is used in scripting to create the secrets locally prior to being committed to the repository.

https://github.com/bitnami-labs/sealed-secrets

# Usage 

1. Fork this repository

1. Update the `REPO_URL` variable in `scripts\flux-init.sh` to point to your fork

   `REPO_URL=${1:-git@github.com:confluentinc/kafka-devops}`

1. To install all dependencies

   `make init`

1. To create a local test cluster using k3d

   `make cluster`

1. Install Bitnami Sealed Secrets Controller into the cluster

	 `make install-bitnami-secret-controller`

1. Create your secrets

	 todo: link to secrets instructions

1. Install Flux into the cluster

   `make install-flux`

   	The script will install Flux into the cluster and then wait for you to add a Deploy Key in the repo with the key provided.

1. Verify the system is deployed

	 `kubectl get all`

## Credits
Significant portions of the repository are based on work by Steven Wade @ https://github.com/swade1987
