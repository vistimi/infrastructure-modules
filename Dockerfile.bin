ARG VARIANT=alpine:3.16
ARG RUNNER=workflow
ARG ALPINE_VARIANT=alpine:3.16
ARG GO_ALPINE_VARIANT=golang:1.19.0-alpine
ARG PYTHON_ALPINE_VARIANT=python:3.10.5-alpine

#---------------------------------
#       BUILDER ALPINE
#---------------------------------
FROM ${ALPINE_VARIANT} as builder-alpine

ARG TARGETOS TARGETARCH

RUN apk update
RUN apk add -q --no-cache git zip gzip tar dpkg make wget

# # rover
# ARG ROVER_VERSION=0.3.3
# RUN mkdir rover && cd rover && wget -q https://github.com/im2nguyen/rover/releases/download/v${ROVER_VERSION}/rover_${ROVER_VERSION}_${TARGETOS}_${TARGETARCH}.zip \
#     && unzip rover_${ROVER_VERSION}_${TARGETOS}_${TARGETARCH}.zip && mv rover_v${ROVER_VERSION} /usr/local/bin/rover \
#     && chmod +rx /usr/local/bin/rover && cd .. && rm -R rover

# terraform
ARG TERRAFORM_VERSION=1.5.2
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip \
    && unzip terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip && mv terraform /usr/local/bin/terraform \
    && chmod +rx /usr/local/bin/terraform && rm terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip

# terragrunt
ARG TERRAGRUNT_VERSION=0.48.0
RUN wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_${TARGETOS}_${TARGETARCH} \
    && mv terragrunt_${TARGETOS}_${TARGETARCH} /usr/local/bin/terragrunt \
    && chmod +rx /usr/local/bin/terragrunt

# cloud-nuke
ARG CLOUD_NUKE_VERSION=0.31.1
RUN wget -q https://github.com/gruntwork-io/cloud-nuke/releases/download/v${CLOUD_NUKE_VERSION}/cloud-nuke_${TARGETOS}_${TARGETARCH} \
    && mv cloud-nuke_${TARGETOS}_${TARGETARCH} /usr/local/bin/cloud-nuke \
    && chmod +rx /usr/local/bin/cloud-nuke

#---------------------------------
#    BUILDER ALPINE GOLANG
#---------------------------------
FROM ${GO_ALPINE_VARIANT} as builder-alpine-go

RUN apk update
RUN apk add -q --no-cache git zip gzip tar dpkg make wget

# # inframap
# RUN git clone https://github.com/cycloidio/inframap && cd inframap && go mod download && make build \
#     && mv inframap /usr/local/bin/inframap  \
#     && chmod +rx /usr/local/bin/inframap && cd .. && rm -R inframap


#-------------------------
#    RUNNER
#-------------------------
FROM ${VARIANT} as runner

RUN apk update
# coreutils for docker inspect
RUN apk add -q --no-cache make gcc libc-dev bash docker coreutils yq jq github-cli aws-cli curl

# Golang setup
COPY --from=builder-alpine-go /usr/local/go/ /usr/local/go/
COPY --from=builder-alpine-go /go/ /go/
ENV GOPATH /go
ENV PATH /usr/local/go/bin:$GOPATH/bin:$PATH
RUN mkdir -p $GOPATH/src $GOPATH/bin && chmod -R 777 $GOPATH
WORKDIR $GOPATH
RUN go version

# cloud-nuke
COPY --from=builder-alpine /usr/local/bin/cloud-nuke /usr/local/bin/cloud-nuke
RUN cloud-nuke --version

# # rover
# RUN apk add -q --no-cache chromium
# COPY --from=builder-alpine /usr/local/bin/rover /usr/local/bin/rover
# RUN rover --version

# # inframap
# RUN apk add -q --no-cache graphviz
# COPY --from=builder-alpine-go /usr/local/bin/inframap /usr/local/bin/inframap
# RUN inframap version

# terraform
COPY --from=builder-alpine /usr/local/bin/terraform /usr/local/bin/terraform
RUN terraform --version

# terragrunt
COPY --from=builder-alpine /usr/local/bin/terragrunt /usr/local/bin/terragrunt
RUN terragrunt --version

# tflint
COPY --from=ghcr.io/terraform-linters/tflint:latest /usr/local/bin/tflint /usr/local/bin/tflint
RUN tflint --version

# github cli
RUN gh --version

# aws cli
RUN aws --version