FROM gradle:latest

ENV GRADLE_USER_HOME=.gradle

# Run the Update
RUN apt-get update && apt-get upgrade -y

# Install awscli
RUN apt-get install -y python3-pip
RUN pip3 install awscli

ENTRYPOINT ["/usr/bin/gradle"]
