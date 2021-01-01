FROM python

# Install hub
RUN apt-get update

# Install lastversion
RUN pip3 install lastversion

ENTRYPOINT ["lastversion"]
