FROM python:2.7
WORKDIR /opt/ccs-calendarserver

# prepare the system...
RUN apt install -y git

# Setup an app user so the container doesn't run as the root user
RUN useradd calendarserver

# Install the application dependencies
COPY bin ./bin/
RUN bin/macOSX.Apple_ccs_to_vjpd_ccs_migration

USER calendarserver

# Copy in the source code
#COPY src ./src
EXPOSE 5000

#CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
CMD [bash]
