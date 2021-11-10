FROM ubuntu:18.04

RUN apt-get update
RUN apt-get update --fix-missing
RUN apt-get install gnupg -y
RUN apt-get update && \
      apt-get install make gcc apt-transport-https ca-certificates curl sudo wget software-properties-common -y

RUN apt-get update

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  apt-key add -
RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

RUN apt-get update && \
    apt-get install docker-ce docker-ce-cli containerd.io -y

RUN wget -q https://storage.googleapis.com/kubernetes-release/release/v1.20.1/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl 

RUN curl -L https://github.com/docker/compose/releases/download/1.27.4/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose


ENTRYPOINT [ "/bin/bash", "-l", "-c" ]
