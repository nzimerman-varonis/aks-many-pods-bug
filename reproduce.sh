#!/bin/bash

set -ex

kubectl --kubeconfig=kubeconfig get nodes
kubectl --kubeconfig=kubeconfig apply -f wait-forever-deployment.yml
kubectl --kubeconfig=kubeconfig rollout status -w deployment/wait-forever
kubectl --kubeconfig=kubeconfig scale --replicas=200 deployment/wait-forever
kubectl --kubeconfig=kubeconfig get deployment -w
