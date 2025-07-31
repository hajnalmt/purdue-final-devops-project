FROM ubuntu:22.04

ARG TOMCAT_VERSION=9.0.107

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install openjdk-17-jdk wget curl && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/tomcat && \
    wget -q https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz -O /tmp/tomcat.tar.gz && \
    tar xzf /tmp/tomcat.tar.gz -C /usr/local/tomcat --strip-components=1 && \
    rm /tmp/tomcat.tar.gz

COPY **/*.war /usr/local/tomcat/webapps/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

CMD ["/usr/local/tomcat/bin/catalina.sh", "run"]
