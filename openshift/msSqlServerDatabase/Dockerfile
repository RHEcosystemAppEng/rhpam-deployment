FROM registry.redhat.io/rhpam-7/rhpam-kieserver-rhel8:7.9.0
COPY ./custom-endpoints-1.0.0-SNAPSHOT.jar /opt/eap/standalone/deployments/ROOT.war/WEB-INF/lib/

ENV EXTENSIONS_INSTALL_DIR=/extensions

COPY ./build ${EXTENSIONS_INSTALL_DIR}
RUN bash -x ${EXTENSIONS_INSTALL_DIR}/install.sh ${EXTENSIONS_INSTALL_DIR}
