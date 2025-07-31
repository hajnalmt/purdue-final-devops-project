# Building a CI/CD Pipeline for a Retail Company

Instead of a remote server/aws account setup I opted to use a local k3d environment, because I can present every task properly this way too, and it won't require too much change to port it to an other cluster.

## Local DevOps k3d Environment for ABC Technologies

This part  describes local DevOps environment set up for the ABC Technologies CI/CD pipeline project, as specified in `README_ABC.md`. The environment is fully automated using a Makefile and leverages k3d (Kubernetes in Docker), Helm, and a suite of open-source DevOps tools. This environment is designed to be reproducible, versioned, and easy to use for all project tasks.

---

### 1. Overview of the Environment

- **Kubernetes Cluster:** Runs locally using [k3d](https://k3d.io/), which creates a lightweight Kubernetes cluster inside Docker containers.
- **Local Docker Registry:** A private registry is created for caching and sharing container images between builds and deployments.
- **Ingress Controller:** [Traefik](https://traefik.io/) is used as the ingress controller, exposing services securely via HTTPS.
- **DevOps Tools:** Jenkins (CI/CD), Prometheus (monitoring), and Grafana (visualization) are installed via Helm charts.
- **TLS:** [cert-manager](https://cert-manager.io/) issues self-signed certificates for all services, enabling secure HTTPS endpoints.
- **DNS:** [nip.io](https://nip.io/) wildcard DNS is used, so no /etc/hosts changes are needed. All services are accessible via `*.127.0.0.1.nip.io`.

---

### 2. Makefile Structure and Targets

The Makefile automates the entire environment setup. It is organized into sections for binary installation, cluster creation, and deployments. Key features:

- **Binaries are installed locally** in the `./bin` directory (gitignored), ensuring no system pollution.
- **All versions are controlled via variables** at the top of the Makefile for easy upgrades and reproducibility.
- **Idempotent targets:** Each make target checks if the resource already exists before creating it, so repeated runs are safe.

### Key Targets

- `install-binaries`: Installs k3d, kubectl, helm, and ansible in `./bin`. This makes the whole installation environment agnostic, only git and make is needed. I fixed up the versions too, so everything is replicable.
- `create-registry`: Creates a local Docker registry for k3d to cache and share images.
- `create-cluster`: Creates the k3d Kubernetes cluster, with persistent storage for containerd and unique machine IDs for each node.
- `deploy-cert-manager`: Installs cert-manager via Helm (with CRDs), only if not already present.
- `deploy-cluster-issuer`: Applies a self-signed ClusterIssuer for cert-manager.
- `deploy-jenkins`, `deploy-prometheus`, `deploy-grafana`: Installs each tool via Helm, using custom values files and only if not already present.
- `deploy-all`: Runs all the above in order, providing a one-command setup.
- `clean`: Deletes the cluster and registry, cleaning up all resources.

---

### 3. k3d Cluster Details

- **Cluster Name:** `devops-cluster`
- **Nodes:** 1 server, 2 agents (customizable via variables)
- **Registry:** `devops-registry` on port 6551
- **Ingress:** Traefik is exposed on port 443 (HTTPS) on localhost
- **Persistent Storage:** Each node has a dedicated containerd data directory, and unique `/etc/machine-id` for stability, restarting or stopping the cluster will make
- **Image Caching:**
  - The local registry allows you to build and push images once, then pull them from the registry for fast, repeatable deployments.
  - k3d is configured to use this registry for all image pulls and pushes.

---

### 4. Service Addresses

All services are exposed via Traefik ingress with TLS, using nip.io DNS:

- **Jenkins:**      https://jenkins.127.0.0.1.nip.io
- **Prometheus:**   https://prometheus.127.0.0.1.nip.io
- **Grafana:**      https://grafana.127.0.0.1.nip.io

> The browser will warn about a self-signed certificate. This is expected for local development.

---

### 5. Helm Charts and Version Management

- **Helm is installed locally** in `./bin` and used for all deployments.
- **Chart versions are pinned** via variables at the top of the Makefile:
  - `CERT_MANAGER_CHART_VERSION`, `JENKINS_CHART_VERSION`, `PROMETHEUS_CHART_VERSION`, `GRAFANA_CHART_VERSION`
- **Custom values files** are provided in the `values/` directory for each chart, configuring ingress, TLS, and storage.
- **Narrowed pvc sizes** every pvc in the charts is reduced to just 1Gi.
- **Upgrades and rollbacks** are easy: just change the version variable and re-run the deploy target.

---

### 6. How to Use This Environment

1. **Clone the repository**
2. **Run:**
   ```sh
   make deploy-all
   ```
   This will:
   - Install all required binaries
   - Create the registry and cluster
   - Install cert-manager and the self-signed issuer
   - Deploy Jenkins, Prometheus, and Grafana with secure ingress

3. **Wait for the services to come up.**
    ```sh
    ./bin/kubectl get pods -A
    ```
    Expected output:
    ```sh
    NAMESPACE      NAME                                                 READY   STATUS      RESTARTS      AGE
    cert-manager   cert-manager-5969544f77-wmgd5                        1/1     Running     4 (13m ago)   20h
    cert-manager   cert-manager-cainjector-65967ff5cc-wp82x             1/1     Running     0             20h
    cert-manager   cert-manager-webhook-7c665868cb-5h7l9                1/1     Running     0             20h
    jenkins        jenkins-0                                            2/2     Running     0             99s
    kube-system    coredns-ccb96694c-jhcnh                              1/1     Running     0             20h
    kube-system    helm-install-traefik-crd-7484q                       0/1     Completed   0             20h
    kube-system    helm-install-traefik-rnk94                           0/1     Completed   0             19h
    kube-system    local-path-provisioner-5cf85fd84d-bhbwn              1/1     Running     0             20h
    kube-system    metrics-server-5985cbc9d7-7q9mx                      1/1     Running     0             20h
    kube-system    svclb-traefik-50c07505-46msp                         2/2     Running     0             19h
    kube-system    svclb-traefik-50c07505-jt57f                         2/2     Running     0             19h
    kube-system    svclb-traefik-50c07505-knjd6                         2/2     Running     0             19h
    kube-system    traefik-5d45fc8cc9-fbw78                             1/1     Running     0             19h
    monitoring     grafana-bdcf4f54d-mbm7j                              1/1     Running     0             20h
    monitoring     prometheus-alertmanager-0                            1/1     Running     0             13m
    monitoring     prometheus-kube-state-metrics-7fb455bd77-t54f5       1/1     Running     0             20h
    monitoring     prometheus-prometheus-node-exporter-cs22z            1/1     Running     0             20h
    monitoring     prometheus-prometheus-node-exporter-rhmxn            1/1     Running     0             20h
    monitoring     prometheus-prometheus-node-exporter-vm89g            1/1     Running     0             20h
    monitoring     prometheus-prometheus-pushgateway-85f98dc7b7-pktbc   1/1     Running     0             20h
    monitoring     prometheus-server-7588b78f9-wlmj4                    2/2     Running     0             19h
    ```

    The ingresses available:
    ```sh
    ./bin/skubectl get ingresses -A
    ```
    Expected Output:
    ```sh
    NAMESPACE    NAME                CLASS     HOSTS                         ADDRESS                            PORTS     AGE
    jenkins      jenkins             traefik   jenkins.127.0.0.1.nip.io      100.64.4.3,100.64.4.4,100.64.4.5   80, 443   4m5s
    monitoring   grafana             traefik   grafana.127.0.0.1.nip.io      100.64.4.3,100.64.4.4,100.64.4.5   80, 443   20h
    monitoring   prometheus-server   traefik   prometheus.127.0.0.1.nip.io   100.64.4.3,100.64.4.4,100.64.4.5   80, 443   20h
    ```
4. **Access the services** at the URLs above.

5. **To clean up:**
   ```sh
   make clean
   ```

---

### 7. Customization and Extensibility

- **Change chart versions** by editing the variables at the top of the Makefile.
- **Edit ingress hostnames or TLS settings** in the `values/` files.
- **Add more tools** by creating new deploy targets and values files.
- **Integrate with CI/CD** by scripting builds and deployments using the Makefile.

---

### 8. Why This Environment?

- **Reproducible:** All dependencies and versions are controlled.
- **Isolated:** No system-level changes; everything is local to the project.
- **Fast:** Local registry and persistent storage speed up builds and deployments.
- **Secure:** All endpoints use HTTPS, even for local development.
- **Flexible:** Easy to extend for new tools or workflows.

---

### 9. References
- [k3d documentation](https://k3d.io/)
- [Helm documentation](https://helm.sh/)
- [cert-manager documentation](https://cert-manager.io/)
- [Traefik documentation](https://doc.traefik.io/traefik/)
- [nip.io](https://nip.io/)

---

This environment is now ready to be used for all ABC Technologies DevOps tasks, including CI/CD, containerization, deployment, and monitoring, as described in the project requirements.

### Creating the pipeline
