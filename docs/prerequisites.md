# Tool prerequisites

The included `Makefile` contains a target to install these on MacOS or they can be installed manually. Details for automated installation in the Usage section.

## ccloud
Required to interact with the Confluent Cloud components managed by this project

https://docs.confluent.io/current/cloud/cli/install.html

## kubectl
Required to interact with your Kubernetes cluster, create secrets, etc...

https://kubernetes.io/docs/tasks/tools/install-kubectl/

## fluxctl

Required to interact with the FluxCD controller inside the Kubernetes cluster

https://docs.fluxcd.io/en/1.18.0/references/fluxctl.html

## k3d
If you'd like to run the project on a local Docker based Kubernetes cluster

https://github.com/rancher/k3d#get

## Kustomize
Environments (dev, stg, prd, etc...) are created by using Kustomize style overlays

https://github.com/kubernetes-sigs/kustomize

## Helm 3
Used to install Flux into the cluster

https://helm.sh/docs/intro/install/

## Bitnami Sealed Secrets Kubeseal
The repository uses sealed secrets and the Bitnami controller for managing secret values. `kubeseal` is used in scripting to seal the secrets locally, which are then committed to the repository.

https://github.com/bitnami-labs/sealed-secrets

## jq
`jq` is used for processing JSON

https://stedolan.github.io/jq/

## yq
`yq` is used for processing YAML

https://github.com/mikefarah/yq

