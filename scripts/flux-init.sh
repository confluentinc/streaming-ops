#!/usr/bin/env bash

set -e

if [[ ! -x "$(command -v kubectl)" ]]; then
    echo "kubectl not found"
    exit 1
fi

if [[ ! -x "$(command -v helm)" ]]; then
    echo "helm not found"
    exit 1
fi

if [[ ! -x "$(command -v fluxctl)" ]]; then
    echo "fluxctl not found"
    exit 1
fi

if [ -z ${GHUSER+x} ]; then
  echo "The GHUSER variable must be set to install FluxCD into the Kubernetes cluster"
  exit 1
fi

ENVIRONMENT=${ENVIRONMENT:-dev}
REPO_URL=${REPO_URL:-git@github.com:confluentinc/streaming-ops}
REPO_GIT_USER=${GHUSER}
REPO_GIT_EMAIL=${GHUSER}@users.noreply.github.com

REPO_GIT_INIT_PATHS="environments/${ENVIRONMENT}\,secrets/sealed/${ENVIRONMENT}"
REPO_BRANCH=${REPO_BRANCH:-main}
REPO_ROOT=$(git rev-parse --show-toplevel)
WAIT_FOR_DEPLOY=${WAIT_FOR_DEPLOY:-true}

helm repo add fluxcd https://charts.fluxcd.io

echo ">>> Installing Flux for ${REPO_URL} only watching the ${REPO_GIT_INIT_PATHS} directory"
helm upgrade -i flux fluxcd/flux --wait \
--set git.url=${REPO_URL} \
--set git.user=${REPO_GIT_USER} \
--set git.email=${REPO_GIT_EMAIL} \
--set git.branch=${REPO_BRANCH} \
--set git.path=${REPO_GIT_INIT_PATHS} \
--set git.label="flux-stamp-${ENVIRONMENT}" \
--set git.pollInterval=1m \
--set git.ciSkip="true" \
--set manifestGeneration=true \
--set registry.pollInterval=1m \
--set sync.state=secret \
--set syncGarbageCollection.enabled=true \
--set registry.disableScanning=true \
--namespace flux \
--create-namespace

if [ "$WAIT_FOR_DEPLOY" == "true" ]; then
	echo ">>> GitHub deploy key"
	kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2

	# wait until flux is able to sync with repo
	echo ">>> Waiting on user to add above deploy key to Github with write access"
	until kubectl logs -n flux deployment/flux | grep event=refreshed
	do
	  sleep 5
	done
	echo ">>> Github deploy key is ready"

	echo ">>> Cluster bootstrap done!"
fi
