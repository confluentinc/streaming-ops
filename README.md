# kafka-devops

Simulated production environment running a streaming application targeting Apache Kafka on Confluent Cloud.
Applications and resources are managed by GitOps with declarative infrastructure, Kubernetes and the [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/).

For the full documentation on the the project see https://docs.confluent.io (TODO: real confluent docs link here).

For basic usage instructions on how to use this project, read on.

# Tool prerequisites

The tools required to utilize this project are detailed in [docs/prerequisites.md](docs/prerequisites.md).

# Confluent Cloud

This demo utilizes [Confluent Cloud](https://www.confluent.io/confluent-cloud/) for Kafka and Schema Registry. In order to run this demo you will need a Confluent Cloud account and the `ccloud` CLI.  The automation provided by this project requires configuring Confluent Cloud credentials in order to manage the cloud services.

# Usage 

If you'd like to run a version of this project in your own cluster, follow the below usage steps. 

1.  This project highlights a GitOps workflow for operating microservices on Kubernetes. Using GitOps will require automation to have read/write access to the repository. Use the GitHub Fork function to create a personal fork of the project and clone it locally.

1.  For GitOps workflows, this project uses [FluxCD](https://www.weave.works/technologies/gitops/).  FluxCD requires read/write access into the code repository in order to perform it's function as the Continuous Delivery (CD) controller.  

    FluxCD is deployed from the `scripts/flux-init.sh` script, the following steps configure Flux.

    * Export the `REPO_URL` variable to point to the git URL of your forked repository from step 1

      `export REPO_URL=git@github.com:your-fork/kafka-devops`

    * Export the `GHUSER` variable with your GitHub username

      `export GHUSER="YOUUSER"`

1.  Install dependencies

    This project requires some local tools to function, see [docs/prerequisites.md](docs/prerequisites.md) for the full list and in order to proceed these tools will need to be installed.

    On macOS you can use a provided `make` target to install the dependencies for you using a combination of manual installations by downloading and install binaries to `/usr/local/bin` and Homebrew. You will be prompted for your adminstrative passwod to install files to `/usr/local/bin`.  

    If you are using another operating system or prefer to manually install the dependencies, you can skip this step.

    ```
    make install-deps 
    ```

1. The project uses Kubernetes to host applications connected to Confluent Cloud Kafka and Schema Registry.  If you'd like to use an existing Kubernetes cluster, you only need to ensure your `kubectl` command is configured to administer it.   If you'd like to create a new local Kubernetes cluster on Docker with [k3d](https://github.com/rancher/k3d) you can use this provided make target:

    ```
    make cluster
    ```

    Verify the cluster is ready:

    ```
    kubectl get nodes
    ```
    ```
    NAME                        STATUS   ROLES    AGE   VERSION
    k3d-kafka-devops-server-0   Ready    master   24s   v1.18.4+k3s1
    k3d-kafka-devops-server-1   Ready    master   15s   v1.18.4+k3s1
    k3d-kafka-devops-server-2   Ready    master   12s   v1.18.4+k3s1
    k3d-kafka-devops-server-3   Ready    master   10s   v1.18.4+k3s1 
    ```

1. Install Bitnami Sealed Secret Controller into the cluster

    This project uses [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to manage secret data. Now that local `kubectl` command is configured for the Kubernetes cluster you will use, install the sealed secret controller with:

    ```
    make install-bitnami-secret-controller
    ```

    Wait for the sealed secret controller to be ready. Run this command until the return value transitions from `null` to `1` (available replica):

    ```
    kubectl get -n kube-system deployment/sealed-secrets-controller -o json | jq '.status.availableReplicas'
    ```

1. Retrieve the secret controller's public key for this environment

    The public key is used to seal the secrets which are then committed to the Git repository.  Only the secret controller, which generated a public/private key pair, can decrypt the sealed secrets inside the Kubernetes cluster.
   
    If your cluster has public nodes (which is true for the local dev cluster setup in these instructions), you can obtain and save the public key using:

    ```
    make get-public-key-dev
    ```
  
    If you are using an existing cluster which is private (`kubeseal` cannot reach the secret controller because of network policies), you will need to copy the secret controller's key from the secret controller's log file into the key file stored locally.  This file need not be checked into the repository, however it is not secret information. However you obtain the public key, it can be stored in `secrets/keys/dev.crt` (the `dev` portion represents the environment you are configuring, these instructions only deal with `dev`).  More details are available in the [Bitnami documentation](https://github.com/bitnami-labs/sealed-secrets#public-key--certificate).

    The remaining setup scripts look in the `secrets/keys/dev.crt` location for the public key in order to encrypt secrets. If you have administrative login to the cluster with `kubectl`, you may be able to get the logs by executing the following command substituting your controllers full pod name (`kubectl get pods -n kube-system`):
  
    ```
    kubectl logs sealed-secrets-controller-6bf8c44ff9-x6skc -n kube-system
    ```
  
    See the Bitnami docs for long term management of secrets and more details on private clusters (https://github.com/bitnami-labs/sealed-secrets/blob/master/docs/GKE.md#private-gke-clusters).

    You can validate your `secrets/key/dev.crt` file contents with:

    ```
    cat secrets/keys/dev.crt
    ```
 
    ```
    -----BEGIN CERTIFICATE-----
    MIIErTCCApWgAwIBAgIQH5QEHe0tYPRHi2fPNkCZITANBgkqhkiG9w0BAQsFADAA
    MB4XDTIwMDkwMjE0MDcwOFoXDTMwMDgzMTE0MDcwOFowADCCAiIwDQYJKoZIhvcN
    AQEBBQADggIPADCCAgoCggIBAKoUaCGavOp4Aqz9b3eTDibdytlq46jsBpBGfF7R
    ...
    pzdWVMSumzZnWE/bu9+OQ4TX0d2p6ka/paOXuOObGOlJclex3lEc3Hw06iL9TnJJ
    K4qei3kT6H/QlcjslyWaJtPO5liZLbjBBitXjONM3A8vLfKXA+3IVHG4QAr39jtv
    2Q==
    -----END CERTIFICATE-----
    ```

1. Create and deploy secrets

    The process for sealing secrets will follow this pattern, example commands follow this explanation:

      1. Create a local text file containing the secrets that are to be sealed. This file contains the raw secret data and should be protected like any secret.
      1. Create a local Kubernetes Secret manifest file using the `kubectl create secret file` and put the file into a staging area.  This puts the secret data into a Kubernetes Secret manifest file to be used by the `kubeseal` tool. This file contains raw secret data (in base64 encoding) and should be protected like any secret.
      1. The `kubeseal` command is ran with the secret controllers public key and the Kubernetes Secret file. This encrypts and creates a sealed secret file. This file contains the sealed secret and can be safely commited to a git repostory as only the secret controller can decrypt the secret with it's internal private key.
      1. Commit and push the sealed secret files to the repository.
      1. The Sealed Secret controller, in your cluster, observes new Sealed Secrets and unseals them inside the Kubernetes Cluster for use by applications inside the cluster. Only the secret controller that produced the public key used to seal the secrets can unseal them.

      The following helps you execute these steps.  In the below commands, the namespace, secret name, and generic secret file name are specific and linked to subsequent commands. Do not change these values without understanding the [scripts/seal-secrets.sh script](scripts/seal-secrets.sh), executed later.

    There are two types secrets required to utilize this project.  

    * `ccloud` CLI login credentials are used to manage the Confluent Cloud resources controlled using the [ccloud operator code](images/ccloud-operator). An example of the layout of the secrets file required can be found in the file [secrets/example-ccloud-secrets.props](secrets/example-ccloud-secrets.props).  Create a local secrets files for your `ccloud` credentials, _ensuring you do not commit them to any repository_. Execte the  `kubectl create secret` command as below passing the path to your `ccloud` credentials file into the `--from-env-file` argument. 

      ```
      kubectl create secret generic cc.ccloud-secrets --namespace=default --from-env-file=<path-to-your-file> --dry-run=client -o yaml > secrets/local-toseal/dev/default-cc.ccloud-secrets.yaml
      ```

    * The microservices demo code utilizes a MySQL database to demonstrate Kafka Connect and Change Data Capture. Credentials for the database are required to be provided.  An example of the layout of this file can be found in the sample [secrets/example-connect-operator-secrets.props](secrets/example-connect-operator-secrets.props). There isn't a need to create a personal copy of the database credentials file as that service is ran entirely inside the demonstrations Kubernetes cluster and is not publically accessible.

      ```
      kubectl create secret generic connect-operator-secrets --namespace=default --from-env-file=./secrets/example-connect-operator-secrets.props --dry-run=client -o yaml > secrets/local-toseal/dev/default-connect-operator-secrets.yaml 
      ```

    The above commands have created generic secret Kubernetes secret manifests from your plain text secrets files and put them into a staging area (`secrets/local-toseal/dev`).  

    Now you will seal the secrets, for the `dev` environment, with the following helper command which uses the `scripts/seal-secrets.sh` script. This command will place the sealed secret in `secrets/sealed/dev`, and these are the files which are safe to commit to the repository. This command will also clear the unsealed secrets from the staging area (`secrets/local-toseal/dev`):

    ```
    make seal-secrets-dev
    ```

    You should see the following:
    ```
    Sealing-secrets-----------------------------------
    ➜ ./scripts/seal-secrets.sh dev
    INFO - Successfully sealed secrets/local-toseal/dev/default-cc.ccloud-secrets.yaml
    INFO - Successfully sealed secrets/local-toseal/dev/default-connect-operator-secrets.yaml
    ```

    * Commit the sealed secret to the repository so that Flux can sync it to the K8s cluster:

    ```
    git add secrets/sealed/dev/.
    git commit -m 'New secrets!'
    git push origin master # (or to the appropriate branch if you are doing GitOps by PR already!)
    ```

1. Install Flux, the GitOps operator, into the cluster

    ```
    make install-flux-dev
    ```

    * The script will install FluxCD into the cluster.  FluxCD requires access to your Git repository in order to faciliate GitOps based continuous delivery.  After installation, FluxCD is waiting for access to the configured GitHub repository.  The script presents you with a deploy key that FluxCD generated. Add this deploy key to your GitHub forked repository under Settings->Deploy keys, giving the key write access to the repository.  Write access is required for Flux to manage Tags to control the syncronized state.  See the [Flux documentation](https://docs.fluxcd.io/en/1.17.1/tutorials/get-started.html#giving-write-access) for more details.

    * After configuring the Deploy Key, you should see the following if the syncronization between Flux and the GitHub repository is setup properly:

      ```
      >>> Github deploy key is ready
      >>> Cluster bootstrap done!
      ```

    * FluxCD now has the ability to perform GitOps based CD and the Kubernetes cluster should begin to materialize with running software.

1. Verify secrets are available

    ```
    kubectl get sealedsecrets.bitnami.com
    kubectl get secrets
    ```

    Combining `kubectl`, `jq`, and `base64`, you can decode the secret file to ensure it has been properly set. This should match the original properties file you created. It's controlled by the GitOps process in the same way the other K8s manifests are, however it's not exposed in the code repository.

    ```
    kubectl get secrets/kafka-secrets -o json | jq -r '.data."kafka.properties"' | base64 -d
    ```

1. Verify the system is deployed, this will show you various Kubernetes resources deployed in the `default` namespace.

    ```
    kubectl get all
    ```

## Info

* FluxCD is configured to sync with the repository once per minute, you can force a syncronization with the command: `make sync`
* You can open a terminal on the cluster with some dev tools available with: `make prompt`

## Credits / Links
* Significant portions of the repository are based on the work of Steven Wade @ https://github.com/swade1987
* The script based Operator patterns in this repository are based on the shell-operator project @ https://github.com/flant/shell-operator
* [FluxCD](https://github.com/fluxcd/flux) is used for GitOps based CD
