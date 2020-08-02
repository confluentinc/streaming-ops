#!/bin/bash

export KUBE_TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)

bash
