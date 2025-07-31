# Makefile for local k3d DevOps environment

K3D_CLUSTER_NAME=devops-cluster
K3D_REGISTRY_NAME=devops-registry
K3D_REGISTRY_PORT=6551
K3D_API_PORT=6550
K3D_TRAEFIK_PORT=443
K3D_SERVER_COUNT=1
K3D_AGENT_COUNT=2

K3D_VERSION=5.8.3
K3D_URL=https://github.com/k3d-io/k3d/releases/download/v$(K3D_VERSION)/k3d-linux-amd64
KUBECTL_VERSION=v1.31.5
KUBECTL_URL=https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/amd64/kubectl
ANSIBLE_VERSION=9.5.1
PYPI_INDEX_URL=https://pypi.org/simple
HELM_VERSION=v3.18.4
HELM_URL=https://get.helm.sh/helm-$(HELM_VERSION)-linux-amd64.tar.gz

CERT_MANAGER_CHART_VERSION=v1.18.2
GRAFANA_CHART_VERSION=9.3.0
JENKINS_CHART_VERSION=5.8.73
PROMETHEUS_CHART_VERSION=27.28.2

BIN_DIR=./bin
K3D_BIN=$(BIN_DIR)/k3d
KUBECTL_BIN=$(BIN_DIR)/kubectl
ANSIBLE_BIN=$(BIN_DIR)/ansible
HELM_BIN=$(BIN_DIR)/helm

.PHONY: install-binaries install-k3d install-kubectl install-ansible install-helm deploy-cert-manager create-registry create-cluster delete-cluster deploy-jenkins deploy-prometheus deploy-grafana deploy-all deploy-cluster-issuer clean

# =====================
# Install Binaries
# =====================
install-binaries: \
  install-k3d \
  install-kubectl \
  install-ansible \
  install-helm
	@echo "All binaries installed in $(BIN_DIR)"

install-k3d:
	@echo "Installing k3d..."
	@mkdir -p $(BIN_DIR)
	@if [ ! -f $(K3D_BIN) ]; then \
		curl -s -L $(K3D_URL) -o $(K3D_BIN); \
		chmod +x $(K3D_BIN); \
	else \
		echo "k3d already installed at $(K3D_BIN)"; \
	fi

install-kubectl:
	@echo "Installing kubectl..."
	@mkdir -p $(BIN_DIR)
	@if [ ! -f $(KUBECTL_BIN) ]; then \
		curl -Lo $(KUBECTL_BIN) $(KUBECTL_URL); \
		chmod +x $(KUBECTL_BIN); \
	else \
		echo "kubectl already installed at $(KUBECTL_BIN)"; \
	fi

install-ansible:
	@echo "Installing ansible $(ANSIBLE_VERSION) (via pipx)..."
	@mkdir -p $(BIN_DIR)
	@if [ ! -f $(ANSIBLE_BIN) ]; then \
		python3 -m pip install --user pipx -i $(PYPI_INDEX_URL) || true; \
		python3 -m pipx ensurepath || true; \
		pipx install --force ansible==$(ANSIBLE_VERSION) --index-url $(PYPI_INDEX_URL) || true; \
		ln -sf $$(pipx list --json | jq -r '.venvs.ansible.metadata.main_package.app_paths_of_dependencies["ansible-core"][] | select(."__Path__" | test("ansible$")) | ."__Path__"') $(BIN_DIR)/ansible; \
		ln -sf $$(pipx list --json | jq -r '.venvs.ansible.metadata.main_package.app_paths_of_dependencies["ansible-core"][] | select(."__Path__" | test("ansible-playbook$")) | ."__Path__"') $(BIN_DIR)/ansible-playbook; \
	else \
		echo "ansible already installed at $(ANSIBLE_BIN)"; \
	fi

install-helm:
	@echo "Installing helm..."
	@mkdir -p $(BIN_DIR)
	@if [ ! -f $(HELM_BIN) ]; then \
		curl -Lo /tmp/helm.tar.gz $(HELM_URL); \
		tar -xzf /tmp/helm.tar.gz -C /tmp; \
		mv /tmp/linux-amd64/helm $(HELM_BIN); \
		chmod +x $(HELM_BIN); \
		rm -rf /tmp/helm.tar.gz /tmp/linux-amd64; \
	else \
		echo "helm already installed at $(HELM_BIN)"; \
	fi

# =====================
# Cluster Creation
# =====================
create-registry:
	@( $(K3D_BIN) registry ls $(K3D_REGISTRY_NAME) && echo "Local registry already exists." ) \
	|| $(K3D_BIN) registry create $(K3D_REGISTRY_NAME) --port 0.0.0.0:$(K3D_REGISTRY_PORT)
	@echo "Registry created at $(K3D_REGISTRY_NAME):$(K3D_REGISTRY_PORT)"

create-cluster:
	@echo "Checking if k3d cluster '$(K3D_CLUSTER_NAME)' exists..."
	@$(K3D_BIN) cluster list $(K3D_CLUSTER_NAME) | grep -q $(K3D_CLUSTER_NAME) && \
		echo "Cluster '$(K3D_CLUSTER_NAME)' already exists." || { \
		echo "Creating k3d cluster..."; \
		mkdir -pv $(PWD)/data/containerd/{server-0,agent-0,agent-1}; \
		[ -e $(PWD)/data/machine-id-server-0 ] || dbus-uuidgen > $(PWD)/data/machine-id-server-0; \
		[ -e $(PWD)/data/machine-id-agent-0 ] || dbus-uuidgen > $(PWD)/data/machine-id-agent-0; \
		[ -e $(PWD)/data/machine-id-agent-1 ] || dbus-uuidgen > $(PWD)/data/machine-id-agent-1; \
		$(K3D_BIN) cluster create $(K3D_CLUSTER_NAME) \
		  --agents $(K3D_AGENT_COUNT) \
		  --api-port $(K3D_API_PORT) \
		  --registry-use $(K3D_REGISTRY_NAME):$(K3D_REGISTRY_PORT) \
		  --volume $(PWD)/data/machine-id-server-0:/etc/machine-id@server:0 \
		  --volume $(PWD)/data/machine-id-agent-0:/etc/machine-id@agent:0 \
		  --volume $(PWD)/data/machine-id-agent-1:/etc/machine-id@agent:1 \
		  --volume $(PWD)/data/containerd/server-0:/var/lib/rancher/k3s/agent/containerd@server:0 \
		  --volume $(PWD)/data/containerd/agent-0:/var/lib/rancher/k3s/agent/containerd@agent:0 \
		  --volume $(PWD)/data/containerd/agent-1:/var/lib/rancher/k3s/agent/containerd@agent:1 \
		  -p $(K3D_TRAEFIK_PORT):443@loadbalancer \
		  --wait; \
	}

delete-cluster:
	@echo "Deleting k3d cluster and registry..."
	-$(K3D_BIN) cluster delete $(K3D_CLUSTER_NAME)
	-$(K3D_BIN) registry delete $(K3D_REGISTRY_NAME)

# =====================
# Deployments
# =====================
deploy-cert-manager:
	@echo "Installing cert-manager via Helm..."
	$(KUBECTL_BIN) create namespace cert-manager --dry-run=client -o yaml | $(KUBECTL_BIN) apply -f -
	$(HELM_BIN) repo add jetstack https://charts.jetstack.io || true
	$(HELM_BIN) repo update
	@if $(HELM_BIN) status cert-manager -n cert-manager > /dev/null 2>&1; then \
		echo "cert-manager release already exists in namespace cert-manager."; \
	else \
		$(HELM_BIN) upgrade --install cert-manager jetstack/cert-manager \
		  --namespace cert-manager \
		  --version $(CERT_MANAGER_CHART_VERSION) \
		  --set installCRDs=true; \
	fi

deploy-cluster-issuer:
	@echo "Applying self-signed ClusterIssuer..."
	$(KUBECTL_BIN) apply -f values/selfsigned-issuer.yaml

deploy-jenkins:
	@echo "Deploying Jenkins via Helm..."
	$(KUBECTL_BIN) create namespace jenkins --dry-run=client -o yaml | $(KUBECTL_BIN) apply -f -
	$(HELM_BIN) repo add jenkins https://charts.jenkins.io || true
	$(HELM_BIN) repo update
	@if $(HELM_BIN) status jenkins -n jenkins > /dev/null 2>&1; then \
		echo "Jenkins release already exists in namespace jenkins."; \
	else \
		$(HELM_BIN) upgrade --install jenkins jenkins/jenkins \
		  --namespace jenkins \
		  --version $(JENKINS_CHART_VERSION) \
		  --values values/jenkins-values.yaml; \
	fi

deploy-prometheus:
	@echo "Deploying Prometheus via Helm..."
	$(KUBECTL_BIN) create namespace monitoring --dry-run=client -o yaml | $(KUBECTL_BIN) apply -f -
	$(HELM_BIN) repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
	$(HELM_BIN) repo update
	@if $(HELM_BIN) status prometheus -n monitoring > /dev/null 2>&1; then \
		echo "Prometheus release already exists in namespace monitoring."; \
	else \
		$(HELM_BIN) upgrade --install prometheus prometheus-community/prometheus \
		  --namespace monitoring \
		  --version $(PROMETHEUS_CHART_VERSION) \
		  --values values/prometheus-values.yaml; \
	fi

deploy-grafana:
	@echo "Deploying Grafana via Helm..."
	$(KUBECTL_BIN) create namespace monitoring --dry-run=client -o yaml | $(KUBECTL_BIN) apply -f -
	$(HELM_BIN) repo add grafana https://grafana.github.io/helm-charts || true
	$(HELM_BIN) repo update
	@if $(HELM_BIN) status grafana -n monitoring > /dev/null 2>&1; then \
		echo "Grafana release already exists in namespace monitoring."; \
	else \
		$(HELM_BIN) upgrade --install grafana grafana/grafana \
		  --namespace monitoring \
		  --version $(GRAFANA_CHART_VERSION) \
		  --values values/grafana-values.yaml; \
	fi

deploy-all: \
  install-binaries \
  create-registry \
  create-cluster \
  deploy-cert-manager \
  deploy-cluster-issuer \
  deploy-jenkins \
  deploy-prometheus \
  deploy-grafana

clean: delete-cluster
	@echo "Cleanup complete."

