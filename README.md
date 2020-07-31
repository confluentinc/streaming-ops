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
The repository uses sealed secrets and the Bitnami controller for managing secret values. `kubeseal` is used in scripting to seal the secrets locally, which are then committed to the repository.

https://github.com/bitnami-labs/sealed-secrets

## jq
https://stedolan.github.io/jq/

## yq
https://github.com/mikefarah/yq

# Confluent Cloud

This demo utilizes Confluent Cloud for Kafka as a service as well as Schema Registry and ksqlDB. In order to run this demo you will need a Confluent Cloud account, the ccloud CLI, and an environment and Kafka cluster setup. 

In the future, all steps (besides account creation), will be automated and managed by operations in this repository. Until there there are some setup steps to make the application function properly.

TOOD: Link to Docs for setting up ccloud and environment properly

# Usage 

1. Fork this repository

1. Update the following variables in `scripts\flux-init.sh`

	* `ENVIRONMENT=dev` You'll complete this process for each environment
	* `REPO_URL=git@github.com:confluentinc/kafka-devops` Update to match your git remote URL
	* `REPO_GIT_USER=rspurgeon` Update to your git username
	* `REPO_GIT_EMAIL=rspurgeon@confluent.io` Update to your git email

1. To install all dependencies on a Mac (uses `sudo` to install binaries to `/usr/local/bin`, so you will be prompted for pwd).

	`make init`

	(Linux instructions to come)

1. To create a local test cluster on Docker using k3d

  `make cluster`

  Verify the cluster is ready:
  ```
  kubectl get nodes
  NAME                        STATUS   ROLES    AGE   VERSION
  k3d-kafka-gitops-server-0   Ready    master   24s   v1.18.4+k3s1
  k3d-kafka-gitops-server-1   Ready    master   15s   v1.18.4+k3s1
  k3d-kafka-gitops-server-2   Ready    master   12s   v1.18.4+k3s1
  k3d-kafka-gitops-server-3   Ready    master   10s   v1.18.4+k3s1 
  ```

1. Install Bitnami Sealed Secrets Controller into the cluster

  `make install-bitnami-secret-controller`
  
  Verify the controller is ready (1 available replica):

  ```
  kubectl get -n kube-system deployment/sealed-secrets-controller -o json | jq '.status.availableReplicas'
  ```

1. Retrieve the secrets controller public key for this environment. The public key is stored in `secrets/keys/<environment>.crt`, _but not checked into the repository_.  See the Bitnami docs for long term management of secrets.

	 `make get-public-key ENV=dev`

1. Create and deploy the sealed secrets 4 steps:

	* Create your secret file, like the example `secrets\example.secret` containing your endpoints and secret values. We are going to store the entire properties file we pass to Kafka clients as a secret. This makes configuring applications in Kubernetes easier. You can obtain this properties file, along with the cloud secrets, from the Confluent Cloud web console under "Tools & client config".
	
	* Use `kubectl` to create a generic secret file from your properties file and put it into a staging area (`secrets/local-toseal`). _The namespace, secret name, and generic secret file name are related in this command, do not change them without understanding the seal script, executed next_.

		`kubectl create secret generic kafka-secrets --namespace=default --from-file=kafka.properties=secrets/example.secret --dry-run=client -o yaml > secrets/local-toseal/dev/default-kafka-secrets.yaml`

	* Seal the secrets, for the `dev` environment, with the following helper command which uses the `scripts/seal-secrets.sh` script. This command will place the sealed secret in `secrets/sealed/dev`, and this is the file which is safe to commit to the repository.

		`make seal-dev`

	* Commit the sealed secret to the repository so that Flux can sync it to the K8s cluster:

		```
		git add secrets/sealed/dev/default-kafka-secrets.yaml
		git commit -m 'New secrets!'
		git push origin master # (or to the appropriate branch if you are doing GitOps by PR already!)
		```

1. Install Flux, the GitOps operator, into the cluster

	`make install-flux`

	The script will install Flux into the cluster and then wait for you to add the shown key to your repository in the Settings->Deploy Keys section. Write access is required for Flux to manage Tags to control the syncronized state.  See the Flux documentation for more details.

1. Verify secrets are available

	`kubectl get sealedsecrets.bitnami.com`

	`kubectl get secrets`

	Combining `kubectl`, `jq`, and `base64`, you can decode the secret file to ensure it has been properly set:

	`kubectl get secrets/kafka-secrets -o json | jq -r '.data."kafka.properties"' | base64 --decode`

1. Verify the system is deployed

	 `kubectl get all`

## Credits
Significant portions of the repository are based on the work of Steven Wade @ https://github.com/swade1987

