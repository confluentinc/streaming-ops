# kafka-devops

Simulated production environment running Kafka and Confluent products managed by declarative infrastructure and GitOps.

# Tool pre-requisites

## k3d
If you'd like to run the example on a local Docker based Kubernetes cluster

## Kustomize
https://github.com/kubernetes-sigs/kustomize

## Helm 3
Used to install Flux into the cluster
https://helm.sh/docs/intro/install/

# Usage 

## Setup
1. Fork this repository
1. Update this variable to point to your fork
   `REPO_URL=${1:-git@github.com:confluentinc/kafka-devops}`
1. To install k3d (and soon other tools)
   `make init`
1. To create a local test cluster
   `make cluster`

To install Flux into the cluster
`make install-flux`
The script will install Flux into the cluster and then wait for you to add a Deploy Key in the repo with the pkey provided.

<docs link here...>
