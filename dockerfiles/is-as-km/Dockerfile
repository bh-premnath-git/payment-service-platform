# set base Docker image to WSO2 API Manager Docker image with latest WSO2 Updates
FROM wso2/wso2is:5.11.0
LABEL maintainer="WSO2 Docker Maintainers <dev@wso2.org>"

# Upgrade to Java 17 to support PKCS12 keystores with HmacPBESHA256
USER root
RUN apt-get update && \
    apt-get install -y wget && \
    wget -O /tmp/openjdk-17.tar.gz https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_linux-x64_bin.tar.gz && \
    tar -xzf /tmp/openjdk-17.tar.gz -C /opt && \
    rm /tmp/openjdk-17.tar.gz && \
    update-alternatives --install /usr/bin/java java /opt/jdk-17.0.2/bin/java 1 && \
    update-alternatives --install /usr/bin/keytool keytool /opt/jdk-17.0.2/bin/keytool 1 && \
    update-alternatives --set java /opt/jdk-17.0.2/bin/java && \
    update-alternatives --set keytool /opt/jdk-17.0.2/bin/keytool && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/opt/jdk-17.0.2
ENV PATH=$JAVA_HOME/bin:$PATH

USER wso2carbon

ARG MYSQL_CONNECTOR_VERSION=8.0.30
# copy extensions to the identity server home
COPY dropins ${WSO2_SERVER_HOME}/repository/components/dropins/
# copy customized webapps to the identity server home
COPY webapps ${WSO2_SERVER_HOME}/repository/deployment/server/webapps/

# add MySQL JDBC connector to server home as a third party library
ADD --chown=wso2carbon:wso2 https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar ${WSO2_SERVER_HOME}/repository/components/lib/
