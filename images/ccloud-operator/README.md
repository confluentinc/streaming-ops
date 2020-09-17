
## ccloud-operator

ccloud-operator is a [shell-operator](https://github.com/flant/shell-operator) based solution for managing Confluent Cloud resources using a declarative approach.   The operator will monitor ConfigMaps with a label (destination=ccloud) and will apply the definition using the `ccloud` CLI tool.
