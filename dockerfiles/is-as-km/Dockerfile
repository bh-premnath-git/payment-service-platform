FROM wso2/wso2is:7.1.0-alpine
LABEL maintainer="WSO2 Docker Maintainers <dev@wso2.org>"

ARG MYSQL_CONNECTOR_VERSION=8.0.30
# copy extensions to the identity server home
COPY dropins ${WSO2_SERVER_HOME}/repository/components/dropins/

COPY --chown=wso2carbon:wso2 --chmod=0755 setup-and-start.sh /home/wso2carbon/setup-and-start.sh
RUN chmod +x /home/wso2carbon/setup-and-start.sh

# add MySQL JDBC connector to server home as a third party library
ADD --chown=wso2carbon:wso2 https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar ${WSO2_SERVER_HOME}/repository/components/lib/
