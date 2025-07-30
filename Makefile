# Makefile for local k3d DevOps environment

K3D_CLUSTER_NAME=devops-cluster
K3D_REGISTRY_NAME=devops-registry
K3D_REGISTRY_PORT=6551
K3D_API_PORT=6550
K3D_TRAEFIK_PORT=8080
K3D_AGENT_COUNT=2

K3D_VERSION=5.8.3
K3D_URL=https://github.com/k3d-io/k3d/releases/download/v$(K3D_VERSION)/k3d-linux-amd64
KUBECTL_VERSION=v1.31.5
KUBECTL_URL=https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/amd64/kubectl
ANSIBLE_VERSION=9.5.1
PYPI_INDEX_URL=https://pypi.org/simple

BIN_DIR=./bin
K3D_BIN=$(BIN_DIR)/k3d
KUBECTL_BIN=$(BIN_DIR)/kubectl
ANSIBLE_BIN=$(BIN_DIR)/ansible

.PHONY: install-binaries create-registry create-cluster delete-cluster deploy-jenkins deploy-prometheus deploy-grafana deploy-all clean

install-binaries:
	@echo "Creating bin directory..."
	@mkdir -p $(BIN_DIR)
	@if [ ! -f $(K3D_BIN) ]; then \
		echo "Installing k3d..."; \
		curl -s -L $(K3D_URL) -o $(K3D_BIN); \
		chmod +x $(K3D_BIN); \
	else \
		echo "k3d already installed at $(K3D_BIN)"; \
	fi
	@if [ ! -f $(KUBECTL_BIN) ]; then \
		echo "Installing kubectl..."; \
		curl -Lo $(KUBECTL_BIN) $(KUBECTL_URL); \
		chmod +x $(KUBECTL_BIN); \
	else \
		echo "kubectl already installed at $(KUBECTL_BIN)"; \
	fi
	@if [ ! -f $(ANSIBLE_BIN) ]; then \
		echo "Installing ansible $(ANSIBLE_VERSION) (via pipx)..."; \
		python3 -m pip install --user pipx -i $(PYPI_INDEX_URL) || true; \
		python3 -m pipx ensurepath || true; \
		pipx install --force ansible==$(ANSIBLE_VERSION) --index-url $(PYPI_INDEX_URL) || true; \
		ln -sf $$(pipx which ansible) $(ANSIBLE_BIN); \
	else \
		echo "ansible already installed at $(ANSIBLE_BIN)"; \
	fi
	@echo "All binaries installed in $(BIN_DIR)"

create-registry:
	@( $(K3D_BIN) registry ls $(K3D_REGISTRY_NAME) && echo "Local registry already exists." ) \
	|| $(K3D_BIN) registry create $(K3D_REGISTRY_NAME) --port 0.0.0.0:$(K3D_REGISTRY_PORT)
	@echo "Registry created at $(K3D_REGISTRY_NAME):$(K3D_REGISTRY_PORT)"

create-cluster:
	@echo "Creating k3d cluster..."
	$(K3D_BIN) cluster create $(K3D_CLUSTER_NAME) \
	  --agents $(K3D_AGENT_COUNT) \
	  --api-port $(K3D_API_PORT) \
	  --registry-use $(K3D_REGISTRY_NAME):$(K3D_REGISTRY_PORT) \
	  -p $(K3D_TRAEFIK_PORT):80@loadbalancer \
	  --wait

delete-cluster:
	@echo "Deleting k3d cluster and registry..."
	-$(K3D_BIN) cluster delete $(K3D_CLUSTER_NAME)
	-$(K3D_BIN) registry delete $(K3D_REGISTRY_NAME)


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


deploy-all: create-registry create-cluster deploy-jenkins deploy-prometheus deploy-grafana

clean: delete-cluster
	@echo "Cleanup complete."
