# Purdue University final devops project
This repository contains the tasks detailed in the final project.
ABCTechnologies directory contains the source code for the Industry grade project1
XYZTexhnologies directory contains the source code for the Industry grade project2

---

## Local DevOps Platform with k3d, Jenkins, Prometheus, Grafana, and TLS

This project provides a Makefile to set up a local Kubernetes (k3d) cluster with:
- Local Docker registry
- Traefik ingress
- Jenkins, Prometheus, and Grafana (via Helm)
- cert-manager for TLS (self-signed)
- nip.io wildcard DNS for easy local access

### Prerequisites
- Linux (tested on Ubuntu/WSL)
- Docker
- Python 3 (for pipx/ansible)

### Quick Start
1. **Clone the repo**
2. **Run the full platform setup:**
   ```sh
   make deploy-all
   ```
   This will:
   - Install k3d, kubectl, helm, ansible (in ./bin)
   - Create a k3d cluster and local registry
   - Install cert-manager and a self-signed ClusterIssuer
   - Deploy Jenkins, Prometheus, and Grafana with TLS and ingress

3. **Access the services:**
   - Jenkins:      https://jenkins.127.0.0.1.nip.io
   - Prometheus:   https://prometheus.127.0.0.1.nip.io
   - Grafana:      https://grafana.127.0.0.1.nip.io

   > The browser will warn about a self-signed certificate. You can safely proceed for local development.

### How it works
- All binaries are installed in the `bin/` directory (which is gitignored).
- All deployments use Helm with custom values files in `values/`.
- Ingress is handled by Traefik and uses nip.io for DNS, so no /etc/hosts edits are needed.
- TLS is provided by cert-manager with a self-signed ClusterIssuer.

### Customization
- To change ingress hostnames, edit the files in `values/`.
- To use a real certificate, replace the ClusterIssuer and update the ingress annotations.

### Clean up
To remove the cluster and all resources:
```sh
make clean
```

---

## Makefile Targets (Summary)
- `install-binaries`   : Install k3d, kubectl, helm, ansible in ./bin
- `create-registry`    : Create a local Docker registry for k3d
- `create-cluster`     : Create the k3d cluster (if not exists)
- `deploy-cert-manager`: Install cert-manager (if not exists)
- `deploy-cluster-issuer`: Apply the self-signed ClusterIssuer
- `deploy-jenkins`     : Deploy Jenkins via Helm (if not exists)
- `deploy-prometheus`  : Deploy Prometheus via Helm (if not exists)
- `deploy-grafana`     : Deploy Grafana via Helm (if not exists)
- `deploy-all`         : Run all the above in order
- `clean`              : Delete the cluster and registry

---

## Notes
- If you want to use your own domain or a trusted CA, update the values files and ClusterIssuer accordingly.
- For more details, see the Makefile and values/ directory.
