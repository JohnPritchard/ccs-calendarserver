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
    less \
    libssl-dev \
    libsasl2-dev \
    libldap2-dev \
    libtool \
    passwd \
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
RUN usermod \
    -a -G staff \
    calendarserver

VOLUME /opt/Calendar_and_Contacts

# Install the application dependencies
COPY bin ./bin/
RUN mkdir -pv \
    /opt/ccs-calendarserver \
    /var/calendarserver \
    /var/run/caldavd \
    /var/run/caldavd_requests
RUN chown -R calendarserver:calendarserver \
    /opt/ccs-calendarserver \
    /var/calendarserver \
    /var/run/caldavd \
    /var/run/caldavd_requests
RUN chmod -R 0770 \
    /var/run/caldavd \
    /var/run/caldavd_requests

USER calendarserver

RUN bin/linux.Apple_ccs_to_vjpd_ccs_migration --exec build_server
RUN bin/linux.Apple_ccs_to_vjpd_ccs_migration --exec configure_server

# expose ports...
EXPOSE 9008
EXPOSE 9443

ENV PATH=/opt/ccs-calendarserver/CalendarServer/bin:/opt/ccs-calendarserver/CalendarServer/virtualenv/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PYTHON=/opt/ccs-calendarserver/CalendarServer/bin/python
ENV LD_LIBRARY_PATH=/opt/ccs-calendarserver/CalendarServer/lib

CMD [\
    "/opt/ccs-calendarserver/CalendarServer/bin/caldavd", \
    "-X", \
    "-R", "default", \
    "-f", "/var/calendarserver/conf/calendarserver.plist" \
]
# sudo -u \#116 bash -x /opt/ccs-calendarserver/CalendarServer/bin/caldavd -X -R kqueue -f /opt/ccs-calendarserver/CalendarServer/conf/calendarserver.plist
#USER root
CMD ["bash"]
# bash -x /opt/ccs-calendarserver/CalendarServer/bin/caldavd -X -R kqueue -f /var/calendarserver/conf/calendarserver.plist
# bash -x /opt/ccs-calendarserver/CalendarServer/bin/caldavd -X -R default -f /var/calendarserver/conf/calendarserver.plist
# tail -n 30 /opt/Calendar_and_Contacts/Logs/error.log
# git pull ; iid=$(sudo docker images | grep ^apple_ccs\  | awk '{print $3}') ; [ ! -z "$iid" ] && sudo docker rmi --force $iid ; sudo docker buildx build . --tag "apple_ccs" && sudo docker run -it --volume /opt/Calendar_and_Contacts:/opt/Calendar_and_Contacts "apple_ccs"
