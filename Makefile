# Makefile for local k3d DevOps environment

K3D_CLUSTER_NAME=devops-cluster
K3D_REGISTRY_NAME=devops-registry
K3D_REGISTRY_PORT=5000
K3D_API_PORT=6550
K3D_TRAEFIK_PORT=8080
K3D_AGENT_COUNT=2

K3D_VERSION=5.8.3
K3D_URL=https://github.com/k3d-io/k3d/releases/download/v$(K3D_VERSION)/k3d-linux-amd64
KUBECTL_VERSION=$(shell curl -L -s https://dl.k8s.io/release/stable.txt)
KUBECTL_URL=https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/amd64/kubectl
ANSIBLE_VERSION=9.5.1

BIN_DIR=./bin
K3D_BIN=$(BIN_DIR)/k3d
KUBECTL_BIN=$(BIN_DIR)/kubectl
ANSIBLE_BIN=$(BIN_DIR)/ansible

.PHONY: install-binaries create-cluster delete-cluster deploy-jenkins deploy-prometheus deploy-grafana deploy-all clean

install-binaries:
	@echo "Creating bin directory..."
	@mkdir -p $(BIN_DIR)
	@echo "Installing k3d..."
	@curl -s -L $(K3D_URL) -o $(K3D_BIN)
	@chmod +x $(K3D_BIN)
	@echo "Installing kubectl..."
	@curl -Lo $(KUBECTL_BIN) $(KUBECTL_URL)
	@chmod +x $(KUBECTL_BIN)
	@echo "Installing ansible $(ANSIBLE_VERSION) (via pipx)..."
	@python3 -m pip install --user pipx || true
	@python3 -m pipx ensurepath || true
	@pipx install --force ansible==$(ANSIBLE_VERSION) || true
	@ln -sf $$(pipx which ansible) $(ANSIBLE_BIN)
	@echo "All binaries installed in $(BIN_DIR)"

create-cluster:
	@echo "Creating k3d registry..."
	-$(K3D_BIN) registry create $${K3D_REGISTRY_NAME} --port $${K3D_REGISTRY_PORT} || true
	@echo "Creating k3d cluster..."
	$(K3D_BIN) cluster create $${K3D_CLUSTER_NAME} \
	  --agents $${K3D_AGENT_COUNT} \
	  --api-port $${K3D_API_PORT} \
	  --registry-use $${K3D_REGISTRY_NAME}:$${K3D_REGISTRY_PORT} \
	  -p $${K3D_TRAEFIK_PORT}:80@loadbalancer \
	  --wait


delete-cluster:
	@echo "Deleting k3d cluster and registry..."
	-$(K3D_BIN) cluster delete $${K3D_CLUSTER_NAME}
	-$(K3D_BIN) registry delete $${K3D_REGISTRY_NAME}


deploy-jenkins:
	@echo "Deploying Jenkins..."
	$(KUBECTL_BIN) create namespace jenkins --dry-run=client -o yaml | $(KUBECTL_BIN) apply -f -
	$(KUBECTL_BIN) apply -n jenkins -f https://raw.githubusercontent.com/jenkinsci/helm-charts/main/charts/jenkins/templates/jenkins-controller-deployment.yaml


deploy-prometheus:
	@echo "Deploying Prometheus..."
	$(KUBECTL_BIN) create namespace monitoring --dry-run=client -o yaml | $(KUBECTL_BIN) apply -f -
	$(KUBECTL_BIN) apply -n monitoring -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml


deploy-grafana:
	@echo "Deploying Grafana..."
	$(KUBECTL_BIN) create namespace monitoring --dry-run=client -o yaml | $(KUBECTL_BIN) apply -f -
	$(KUBECTL_BIN) apply -n monitoring -f https://raw.githubusercontent.com/grafana/helm-charts/main/charts/grafana/templates/deployment.yaml


deploy-all: create-cluster deploy-jenkins deploy-prometheus deploy-grafana

clean: delete-cluster
	@echo "Cleanup complete."
