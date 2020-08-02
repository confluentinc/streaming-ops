#!/bin/bash

until [ $(kubectl get -n kube-system deployment/sealed-secrets-controller -o json | jq '.status.availableReplicas') == "1" ]; do
	echo "waiting for secret controller"
	sleep 10;
done

echo "secret controller ready"
