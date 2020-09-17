## connect-operator

connect-operator is a [shell-operator](https://github.com/flant/shell-operator) based solution for managing Kafka Connect Connector deployments using a declarative approach.   The operator will monitor ConfigMaps with a label (destination=connect) and will apply the definition using the Kafka Connect REST API.
