FROM python

# Environment
ENV GOBIN=/go/bin

# Install go
# Install lastversion
# Install semver
RUN apt-get update \
    && apt-get install -y apt-utils golang \
    && pip3 install lastversion \
    && pip3 install javaproperties-cli \
    && go get -u github.com/maykonlf/semver-cli/cmd/semver

COPY entrypoint.sh .

RUN chmod u+x entrypoint.sh

# go install bin
ENV PATH=/:$GOBIN:$PATH

ENTRYPOINT ["entrypoint.sh"]
