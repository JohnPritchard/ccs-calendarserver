FROM python:2.7
WORKDIR /opt/ccs-calendarserver

# Install the application dependencies
COPY requirements.txt ./
RUN python2.17 -m pip install --no-cache-dir -r requirements.txt

# Copy in the source code
#COPY src ./src
EXPOSE 5000

# Setup an app user so the container doesn't run as the root user
RUN useradd calendarserver
USER calendarserver

#CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
CMD [bash]
