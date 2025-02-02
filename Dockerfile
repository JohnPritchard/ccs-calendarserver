FROM python:2.7
WORKDIR /opt/ccs-calendarserver

# prepare the system...
RUN apt update
RUN apt install -y \
    automake \
    autotools-dev \
    bash \
    coreutils \
    g++ \
    git \
    libssl-dev \
    libsasl2-dev \
    libldap2-dev \
    libtool \
    pkg-config \
    rsync \
    sudo
RUN apt remove -y python2.7-minimal
RUN apt -y autoremove
RUN ln -s /usr/local/bin/python2.7 /usr/bin/python2.7
RUN ln -s /usr/local/bin/python2.7 /usr/bin/python

# Setup an app user so the container doesn't run as the root user
RUN groupadd \
    --gid 129 \
    calendarserver
RUN useradd \
    --uid 116 \
    --gid 129 \
    calendarserver

VOLUME /opt/Calendar\ and\ Contacts

# Install the application dependencies
RUN rm /bin/sh
RUN ln -s bash /bin/sh
COPY bin ./bin/
RUN chown -R calendarserver:calendarserver /opt/ccs-calendarserver

USER calendarserver

RUN bin/linux.Apple_ccs_to_vjpd_ccs_migration --exec pre_build
RUN bin/linux.Apple_ccs_to_vjpd_ccs_migration --exec build_server
RUN bin/linux.Apple_ccs_to_vjpd_ccs_migration --exec configure_server

# expose ports...
EXPOSE 9008
EXPOSE 9443

ENV PATH=/opt/ccs-calendarserver/CalendarServer/bin:/opt/ccs-calendarserver/CalendarServer/virtualenv/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PYTHON=/opt/ccs-calendarserver/CalendarServer/bin/python

CMD [\
    "/opt/ccs-calendarserver/CalendarServer/bin/caldavd", \
    "-X", \
    "-R", "kqueue", \
    "-f", "/opt/ccs-calendarserver/CalendarServer/conf/calendarserver.plist" \
]
USER root
CMD ["bash"]
