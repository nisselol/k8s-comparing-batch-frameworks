#!/bin/bash
set -e

CLUSTER_NAME="scheduler-test-cluster"
CONFIG_FILE="kind-config.yaml"

echo "!!!Creating kind cluster with name: $CLUSTER_NAME"
kind create cluster --name $CLUSTER_NAME --config $CONFIG_FILE

echo "!!! Checking cluster status..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "!!! Adding helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add yunikorn https://apache.github.io/yunikorn-release
helm repo update

echo "!!! Installing Prometheus and Grafana..."
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.scrapeInterval=10s \
  --wait --timeout 300s

echo "!!! Installing Kueue..."
helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
  --version=0.17.1 \
  --namespace kueue-system \
  --create-namespace \
  --wait --timeout 300s

echo "!!! Configuring Kueue..."
kubectl apply -f clusters/kueue/kueue-config.yaml

echo "!!! Configuring Prometheus to scrape Kueue metrics..."
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.17.1/prometheus.yaml

echo "!!! Installing YuniKorn..."
helm install yunikorn yunikorn/yunikorn \
  --namespace yunikorn --create-namespace \
  --wait --timeout 300s

echo "!!! Cluster setup complete!"
echo "Port forwad Grafana: kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring"
echo "get Grafana admin password: kubectl --namespace monitoring get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo"
echo "Port forwad Prometheus: kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring"