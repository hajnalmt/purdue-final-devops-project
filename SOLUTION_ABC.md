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

## Creating the pipeline

The repository is cloned out, let's do the tasks one by one.

## Task 1:
Clone the project from git hub link shared in resources to your local machine. Build the code
using maven commands.

### ABCTechnologies Maven Makefile Integration

A dedicated `Makefile.ABCTech` is placed in the root of the repository. This file provides convenient targets for compiling, testing, packaging, cleaning, and installing the Maven project in the `ABCTechnologies` directory, all using Dockerized Maven. This approach ensures a consistent build environment without requiring Maven or Java to be installed on the host system.

To use these targets, run the following commands from the project root, specifying the Makefile with `-f`:

```
make -f Makefile.ABCTech compile      # Compiles the ABCTechnologies Maven project
make -f Makefile.ABCTech test         # Runs tests
make -f Makefile.ABCTech package      # Packages the project
make -f Makefile.ABCTech clean        # Cleans the build
make -f Makefile.ABCTech install      # Cleans and installs the project
```

All commands are executed in a Maven Docker container, mounting the `ABCTechnologies` directory for isolation and reproducibility.

This setup is ideal for CI/CD and local development, ensuring builds are always performed in a clean, controlled environment.

#### Example output for each command:

Let's compile:
```sh
make -f Makefile.ABCTech compile
```
Output:
```sh
docker run --rm -v /home/uih20178/Github/purdue-final-devops-project/ABCTechnologies:/app -w /app maven:3.9.6-eclipse-temurin-17 mvn compile
Unable to find image 'maven:3.9.6-eclipse-temurin-17' locally
3.9.6-eclipse-temurin-17: Pulling from library/maven
4a023cab5400: Pull complete
5e5d1bccc544: Pull complete
d59fd278c1b4: Pull complete
c97285723537: Pull complete
a3ba11f7aaae: Pull complete
67f99c2668af: Pull complete
45f480637770: Pull complete
58c3491a14eb: Pull complete
4712dfa85971: Pull complete
fc06d68d71ba: Pull complete
Digest: sha256:29a1658b1f3078e07c2b17f7b519b45eb47f65d9628e887eac45a8c5c8f939d4
Status: Downloaded newer image for maven:3.9.6-eclipse-temurin-17
[INFO] Scanning for projects...
[INFO]
[INFO] ----------------------< com.abc:ABCtechnologies >-----------------------
[INFO] Building RetailModule 1.0
[INFO]   from pom.xml
[INFO] --------------------------------[ war ]---------------------------------
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom (4.4 kB at 16 kB/s)
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/org.jacoco.build/0.8.6/org.jacoco.build-0.8.6.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/org.jacoco.build/0.8.6/org.jacoco.build-0.8.6.pom (42 kB at 1.1 MB/s)
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.jar
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.jar (53 kB at 1.9 MB/s)
Downloading from central: https://repo.maven.apache.org/maven2/org/apache/maven/plugins/maven-resources-plugin/3.3.1/maven-resources-plugin-3.3.1.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/apache/maven/plugins/maven-resources-plugin/3.3.1/maven-resources-plugin-3.3.1.pom (8.2 kB at 544 kB/s)
...
Downloaded from central: https://repo.maven.apache.org/maven2/org/codehaus/plexus/plexus-compiler-manager/2.13.0/plexus-compiler-manager-2.13.0.jar (4.7 kB at 36 kB/s)
Downloaded from central: https://repo.maven.apache.org/maven2/org/codehaus/plexus/plexus-compiler-javac/2.13.0/plexus-compiler-javac-2.13.0.jar (23 kB at 163 kB/s)
Downloaded from central: https://repo.maven.apache.org/maven2/org/codehaus/plexus/plexus-utils/3.5.0/plexus-utils-3.5.0.jar (267 kB at 1.6 MB/s)
[INFO] Changes detected - recompiling the module! :source
[INFO] Compiling 3 source files with javac [debug target 1.8] to target/classes
[WARNING] bootstrap class path not set in conjunction with -source 8
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  3.933 s
[INFO] Finished at: 2025-07-31T09:59:55Z
[INFO] ------------------------------------------------------------------------
```

Then test:
```sh
make -f Makefile.ABCTech test
```
Example output:
```sh
docker run --rm -v /home/uih20178/Github/purdue-final-devops-project/ABCTechnologies:/app -w /app maven:3.9.6-eclipse-temurin-17 mvn test
[INFO] Scanning for projects...
[INFO]
[INFO] ----------------------< com.abc:ABCtechnologies >-----------------------
[INFO] Building RetailModule 1.0
[INFO]   from pom.xml
[INFO] --------------------------------[ war ]---------------------------------
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom (4.4 kB at 17 kB/s)
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/org.jacoco.build/0.8.6/org.jacoco.build-0.8.6.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/org.jacoco.build/0.8.6/org.jacoco.build-0.8.6.pom (42 kB at 1.1 MB/s)
...
Downloaded from central: https://repo.maven.apache.org/maven2/org/apache/maven/surefire/common-junit3/3.2.2/common-junit3-3.2.2.jar (12 kB at 918 kB/s)
Downloaded from central: https://repo.maven.apache.org/maven2/org/apache/maven/surefire/common-junit4/3.2.2/common-junit4-3.2.2.jar (26 kB at 2.0 MB/s)
Downloaded from central: https://repo.maven.apache.org/maven2/org/apache/maven/surefire/common-java5/3.2.2/common-java5-3.2.2.jar (18 kB at 878 kB/s)
[INFO]
[INFO] -------------------------------------------------------
[INFO]  T E S T S
[INFO] -------------------------------------------------------
[INFO] Running com.abc.dataAccessObject.ProductImpTest
[INFO] Tests run: 4, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 0.041 s -- in com.abc.dataAccessObject.ProductImpTest
[INFO]
[INFO] Results:
[INFO]
[INFO] Tests run: 4, Failures: 0, Errors: 0, Skipped: 0
[INFO]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  9.176 s
[INFO] Finished at: 2025-07-31T10:01:07Z
[INFO] ------------------------------------------------------------------------
```

Then package:
```sh
make -f Makefile.ABCTech package
```
Example output:
```sh
docker run --rm -v /home/uih20178/Github/purdue-final-devops-project/ABCTechnologies:/app -w /app maven:3.9.6-eclipse-temurin-17 mvn package
[INFO] Scanning for projects...
[INFO]
[INFO] ----------------------< com.abc:ABCtechnologies >-----------------------
[INFO] Building RetailModule 1.0
[INFO]   from pom.xml
[INFO] --------------------------------[ war ]---------------------------------
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom (4.4 kB at 16 kB/s)
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/org.jacoco.build/0.8.6/org.jacoco.build-0.8.6.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/org.jacoco.build/0.8.6/org.jacoco.build-0.8.6.pom (42 kB at 1.0 MB/s)
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.jar
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.jar (53 kB at 1.1 MB/s)
...
Downloaded from central: https://repo.maven.apache.org/maven2/org/apache/maven/shared/maven-mapping/3.0.0/maven-mapping-3.0.0.jar (11 kB at 82 kB/s)
Downloaded from central: https://repo.maven.apache.org/maven2/com/thoughtworks/xstream/xstream/1.4.10/xstream-1.4.10.jar (590 kB at 3.8 MB/s)
[INFO] Packaging webapp
[INFO] Assembling webapp [ABCtechnologies] in [/app/target/ABCtechnologies-1.0]
[INFO] Processing war project
[INFO] Copying webapp resources [/app/src/main/webapp]
[INFO] Webapp assembled in [42 msecs]
[INFO] Building war: /app/target/ABCtechnologies-1.0.war
[INFO]
[INFO] --- jacoco:0.8.6:report (jacoco-site) @ ABCtechnologies ---
[INFO] Loading execution data file /app/target/jacoco.exec
[INFO] Analyzed bundle 'RetailModule' with 2 classes
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  7.866 s
[INFO] Finished at: 2025-07-31T11:42:41Z
[INFO] ------------------------------------------------------------------------
```

Then try out the clean:

```sh
make -f Makefile.ABCTech clean
```
Example output:
```sh
docker run --rm -v /home/uih20178/Github/purdue-final-devops-project/ABCTechnologies:/app -w /app maven:3.9.6-eclipse-temurin-17 mvn clean
[INFO] Scanning for projects...
[INFO]
[INFO] ----------------------< com.abc:ABCtechnologies >-----------------------
[INFO] Building RetailModule 1.0
[INFO]   from pom.xml
[INFO] --------------------------------[ war ]---------------------------------
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom (4.4 kB at 20 kB/s)
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/org.jacoco.build/0.8.6/org.jacoco.build-0.8.6.pom
...
Downloading from central: https://repo.maven.apache.org/maven2/commons-io/commons-io/2.6/commons-io-2.6.jar
Downloaded from central: https://repo.maven.apache.org/maven2/commons-io/commons-io/2.6/commons-io-2.6.jar (215 kB at 7.4 MB/s)
[INFO] Deleting /app/target
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  0.928 s
[INFO] Finished at: 2025-07-31T11:37:23Z
[INFO] ------------------------------------------------------------------------
```

We can run a clean install too:
```sh
make -f Makefile.ABCTech clean install
```
Example output:
```sh
docker run --rm -v /home/uih20178/Github/purdue-final-devops-project/ABCTechnologies:/app -w /app maven:3.9.6-eclipse-temurin-17 mvn clean
[INFO] Scanning for projects...
[INFO]
[INFO] ----------------------< com.abc:ABCtechnologies >-----------------------
[INFO] Building RetailModule 1.0
[INFO]   from pom.xml
[INFO] --------------------------------[ war ]---------------------------------
Downloading from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom
Downloaded from central: https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.6/jacoco-maven-plugin-0.8.6.pom (4.4 kB at 14 kB/s)
...
Downloaded from central: https://repo.maven.apache.org/maven2/org/codehaus/plexus/plexus-utils/3.1.0/plexus-utils-3.1.0.jar (262 kB at 1.7 MB/s)
[INFO] Packaging webapp
[INFO] Assembling webapp [ABCtechnologies] in [/app/target/ABCtechnologies-1.0]
[INFO] Processing war project
[INFO] Copying webapp resources [/app/src/main/webapp]
[INFO] Webapp assembled in [48 msecs]
[INFO] Building war: /app/target/ABCtechnologies-1.0.war
[INFO]
[INFO] --- jacoco:0.8.6:report (jacoco-site) @ ABCtechnologies ---
[INFO] Loading execution data file /app/target/jacoco.exec
[INFO] Analyzed bundle 'RetailModule' with 2 classes
[INFO]
[INFO] --- install:3.1.1:install (default-install) @ ABCtechnologies ---
[INFO] Installing /app/pom.xml to /root/.m2/repository/com/abc/ABCtechnologies/1.0/ABCtechnologies-1.0.pom
[INFO] Installing /app/target/ABCtechnologies-1.0.war to /root/.m2/repository/com/abc/ABCtechnologies/1.0/ABCtechnologies-1.0.war
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  7.499 s
[INFO] Finished at: 2025-07-31T11:38:34Z
[INFO] ------------------------------------------------------------------------
```

## Task 2
Setup git repository and push the source code. Login to Jenkins
1. create 3 jobs
  - One for compiling source code
  - Second for testing source code
  - Third for packing the code
2. Setup CICD pipeline to execute the jobs created in step1
3. Setup master-slave node to distribute the tasks in pipeline

### Repository

The repository is available at:
https://github.com/hajnalmt/purdue-final-devops-project

### Login to jenkins
Admin credentials are available in the base secret:

User:
```sh
 ./bin/kubectl get secrets -n jenkins jenkins -o json  | jq -r '.data."jenkins-admin-user"' |
base64 -d
```
Example output:
```sh
admin
```

Password
```sh
./bin/kubectl get secrets -n jenkins jenkins -o json  | jq -r '.data."jenkins-admin-password"' | base64 -d
```
Example output:
```sh
iy3pZITxcIRXUUcpMQ1km3
```

![image](./assets/login_to_jenkins.png)

### About the plugins:
The kubernetes and docker plugins should be available.
Go to Manage Jenkins → Manage Plugins and search for them.

Verifying kubernetes plugin availability :
![image](./assets/jenkins_kubernetes_plugin_is_available.png)

Docker plugin wasn't installed for me:
I installed them:
![image](./assets/jenkins_install_docker_plugins1.png)
![image](./assets/jenkins_install_docker_plugins2.png)

### Let's use the kubernetes k3d cluster in place to start our agents!
For earlier release we need to add a Kubernetes Cloud:

Go to “Manage Jenkins” → “System Configuration” → “Clouds”.
Add a new “Kubernetes” cloud.
Set Kubernetes URL to https://kubernetes.default (in-cluster) or your cluster’s API endpoint.
Credentials: Use “Kubernetes Service Account” (default for in-cluster Jenkins).
Test Connection.

This is already there for us!
![image](./assets/jenkins_local_kubernetes1.png)
![image](./assets/jenkins_local_kubernetes2.png)

Let's create a Pod template:
![image](./assets/jenkins_maven_agent_pod_template.png)
![image](./assets/jenkins_maven_agent_pod_template_container.png)
