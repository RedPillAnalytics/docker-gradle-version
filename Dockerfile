FROM python

# Install go
# Install lastversion
# Install semver
RUN apt-get update \
    && apt-get install -y apt-utils golang \
    && pip3 install lastversion \
    && go get -u github.com/maykonlf/semver-cli/cmd/semver

COPY entrypoint.sh .

RUN chmod u+x entrypoint.sh

# go install bin
ENV PATH=~/go/bin:/:$PATH

ENTRYPOINT ["entrypoint.sh"]
