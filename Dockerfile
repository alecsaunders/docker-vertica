FROM centos:centos7

ARG VERTICA_PACKAGE="vertica.rpm"

ENV LANG en_US.utf8
ENV TZ UTC

ADD packages/${VERTICA_PACKAGE} /tmp/

RUN yum -q -y update \
  && yum -q -y install \
    iproute \
    openssl \
    gdb \
    mcelog \
    openssh \
    sysstat \
    which

RUN yum localinstall -q -y /tmp/${VERTICA_PACKAGE}

RUN /opt/vertica/sbin/install_vertica --license CE --accept-eula --hosts 127.0.0.1 \
  --dba-user-password-disabled --failure-threshold NONE --no-system-configuration \
  && /bin/rm -f /tmp/vertica*

ENV PATH=/opt/vertica/bin:/opt/vertica/packages/kafka/bin:${PATH}
RUN echo "export PATH=/opt/vertica/bin:/opt/vertica/packages/kafka/bin:${PATH}" >> /home/dbadmin/.bashrc
RUN chown -R dbadmin: /opt/vertica

ADD --chown=root:root ./docker-entrypoint.sh /opt/vertica/bin/

EXPOSE 5433

ENTRYPOINT ["/bin/bash", "/opt/vertica/bin/docker-entrypoint.sh"]
