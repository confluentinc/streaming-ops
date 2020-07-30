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

1. Update the following variables in `scripts\flux-init.sh`

	* `ENVIRONMENT=dev` You'll complete this process for each environment
	* `REPO_URL=git@github.com:confluentinc/kafka-devops` Update to match your git remote URL
	* `REPO_GIT_USER=rspurgeon` Update to your git username
	* `REPO_GIT_EMAIL=rspurgeon@confluent.io` Update to your git email

1. To install all dependencies on a Mac.  Uses `sudo` to install binaries to `/usr/local/bin`

	`make init`

	(Linux instructions to come)

1. To create a local test cluster on Docker using k3d

   `make cluster`

1. Install Bitnami Sealed Secrets Controller into the cluster

	 `make install-bitnami-secret-controller`

1. Retrieve the secrets controller public key for this environment. The public key is stored in `secrets/keys/<environment>.crt`

	 `make get-public-key ENV=dev`

1. Create your secrets, commit and push them to the repository

	* Create a file like the example `secrets\example.secret` containing your secret values.
	* `kubectl create secret generic kafka-secrets --namespace=default --from-env-file=secrets/example.secret --dry-run=client -o yaml > secrets/local-toseal/dev/default-kafka-secrets.yaml`
		* The output file name, the secret name, and the namespace are all linked with the above command. Study the `scripts/seal-secrets.sh` script before executing with different values.
	* `make seal-dev`
	* `git add secrets/sealed/dev/default-kafka-secrets.yaml`
	* `git commit -m 'New secrets!'
  * `git push origin master`
		* or to the appropriate branch if you are doing GitOps by PR already!

1. Install Flux into the cluster

   `make install-flux`

   	The script will install Flux into the cluster and then wait for you to add a Deploy Key in the repo with the key provided.

1. Verify secrets are available

	 `kubectl get sealedsecrets.bitnami.com`
	 `kubectl get secrets`

1. Verify the system is deployed

	 `kubectl get all`

## Credits
Significant portions of the repository are based on the work of Steven Wade @ https://github.com/swade1987

