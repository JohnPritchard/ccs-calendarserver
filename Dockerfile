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
    libtool \
    pkg-config \
    rsync \
    sudo
RUN apt remove python2.7-minimal
RUN ln -s /usr/local/bin/python2.7 /usr/bin/python2.7
RUN ln -s /usr/local/bin/python2.7 /usr/bin/python

# Setup an app user so the container doesn't run as the root user
RUN useradd calendarserver

# Install the application dependencies
COPY bin ./bin/
#RUN bin/linux.Apple_ccs_to_vjpd_ccs_migration

#USER calendarserver

# Copy in the source code
#COPY src ./src
EXPOSE 5000

#CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
#CMD ["/usr/bin/bash"]
CMD ["bash"]
#CMD ["ls -al", ";", "pwdæ]
