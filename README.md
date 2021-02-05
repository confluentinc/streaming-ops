# DevOps for Apache Kafka®

Simulated production environment running a streaming application targeting Kafka on Confluent Cloud. Applications and resources are managed by GitOps with declarative infrastructure, Kubernetes, and the [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/).

The full usage documentation for this project can be found on [this Confluent documentation page](https://docs.confluent.io/platform/current/tutorials/streaming-ops/index.html).

This project is the subject of the following Confluent Blog post discussing the concepts of DevOps with Kubernetes and Event Streaming Platforms: [DevOps for Apache Kafka® with Kubernetes and GitOps](https://www.confluent.io/blog/devops-for-apache-kafka-with-kubernetes-and-gitops/)

## Credits / Links
* Significant portions of the repository are based on the work of Steven Wade @ https://github.com/swade1987
* The script based Operator patterns in this repository are based on the shell-operator project @ https://github.com/flant/shell-operator
* [FluxCD](https://github.com/fluxcd/flux) is used for GitOps based CD
* [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) are used for secret management in Kubernetes
