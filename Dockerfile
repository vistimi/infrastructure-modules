ARG VARIANT=alpine:3.16
ARG RUNNER=workflow
ARG ALPINE_VARIANT=alpine:3.16
ARG GO_ALPINE_VARIANT=golang:1.19.0-alpine
ARG PYTHON_ALPINE_VARIANT=python:3.10.5-alpine

#---------------------------------
#       BUILDER ALPINE
#---------------------------------
FROM ${ALPINE_VARIANT} as builder-alpine

RUN apk update
RUN apk add -q --no-cache git zip gzip tar dpkg make wget

# rover
ARG ROVER_VERSION=0.3.3
RUN mkdir rover && cd rover && wget -q https://github.com/im2nguyen/rover/releases/download/v${ROVER_VERSION}/rover_${ROVER_VERSION}_linux_amd64.zip \
    && unzip rover_${ROVER_VERSION}_linux_amd64.zip && mv rover_v${ROVER_VERSION} /usr/local/bin/rover \
    && chmod +rx /usr/local/bin/rover && cd .. && rm -R rover

# terraform
ARG TERRAFORM_VERSION=1.4.6
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && mv terraform /usr/local/bin/terraform \
    && chmod +rx /usr/local/bin/terraform && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# terragrunt
ARG TERRAGRUNT_VERSION=0.45.17
RUN wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 \
    && mv terragrunt_linux_amd64 /usr/local/bin/terragrunt \
    && chmod +rx /usr/local/bin/terragrunt

# cloud-nuke
ARG CLOUD_NUKE_VERSION=0.31.1
RUN wget -q https://github.com/gruntwork-io/cloud-nuke/releases/download/v${CLOUD_NUKE_VERSION}/cloud-nuke_linux_amd64 \
    && mv cloud-nuke_linux_amd64 /usr/local/bin/cloud-nuke \
    && chmod +rx /usr/local/bin/cloud-nuke

#---------------------------------
#    BUILDER ALPINE PYTHON
#---------------------------------
FROM ${PYTHON_ALPINE_VARIANT} as builder-alpine-python

ARG AWS_CLI_VERSION=2.9.0
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake
RUN git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

WORKDIR /aws-cli
RUN python -m venv venv
RUN . venv/bin/activate
RUN scripts/installers/make-exe
RUN unzip -q dist/awscli-exe.zip
RUN aws/install --bin-dir /aws-cli-bin
RUN /aws-cli-bin/aws --version

# reduce image size: remove autocomplete and examples
RUN rm -rf \
    /usr/local/aws-cli/v2/current/dist/aws_completer \
    /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
    /usr/local/aws-cli/v2/current/dist/awscli/examples
RUN find /usr/local/aws-cli/v2/current/dist/awscli/data -name completions-1*.json -delete
RUN find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

#---------------------------------
#    BUILDER ALPINE GOLANG
#---------------------------------
FROM ${GO_ALPINE_VARIANT} as builder-alpine-go

RUN apk update
RUN apk add -q --no-cache git zip gzip tar dpkg make wget

# inframap
RUN git clone https://github.com/cycloidio/inframap && cd inframap && go mod download && make build \
    && mv inframap /usr/local/bin/inframap  \
    && chmod +rx /usr/local/bin/inframap && cd .. && rm -R inframap

#-------------------------
#    RUNNER
#-------------------------
FROM ${VARIANT} as runner

RUN apk update
RUN apk add -q --no-cache make gcc libc-dev bash

RUN apk add --no-cache shadow sudo
ARG USERNAME=user
ARG USER_UID=1001
ARG USER_GID=$USER_UID
RUN addgroup --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # Add sudo support. Omit if you don't need to install software after connecting.
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
USER $USERNAME

# Golang setup
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine-go /usr/local/go/ /usr/local/go/
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine-go /go/ /go/
ENV GOPATH /go
ENV PATH /usr/local/go/bin:$GOPATH/bin:$PATH
RUN sudo mkdir -p $GOPATH/src $GOPATH/bin && sudo chmod -R 777 $GOPATH
WORKDIR $GOPATH
RUN go version

# Golang tools
RUN go install github.com/cweill/gotests/gotests@latest \
    && go install github.com/fatih/gomodifytags@latest \
    && go install github.com/josharian/impl@latest \
    && go install github.com/haya14busa/goplay/cmd/goplay@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install honnef.co/go/tools/cmd/staticcheck@latest \
    && go install golang.org/x/tools/gopls@latest

# cloud-nuke
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine /usr/local/bin/cloud-nuke /usr/local/bin/cloud-nuke
RUN cloud-nuke --version

# rover
RUN sudo apk add -q --no-cache chromium
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine /usr/local/bin/rover /usr/local/bin/rover
RUN rover --version

# inframap
RUN sudo apk add -q --no-cache graphviz
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine-go /usr/local/bin/inframap /usr/local/bin/inframap
RUN inframap version

# terraform
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine /usr/local/bin/terraform /usr/local/bin/terraform
RUN terraform --version

# terratest
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine /usr/local/bin/terragrunt /usr/local/bin/terragrunt
RUN terragrunt --version

# tflint
COPY --chown=$USERNAME:$USER_GID --from=ghcr.io/terraform-linters/tflint:v0.43.0 /usr/local/bin/tflint /usr/local/bin/tflint
RUN tflint --version

# github cli
RUN sudo apk add --no-cache -q github-cli && gh --version

# aws cli
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine-python /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --chown=$USERNAME:$USER_GID --from=builder-alpine-python /aws-cli-bin/ /usr/local/bin/
RUN aws --version

# encryption
# RUN sudo apk add --no-cache libsodium-dev