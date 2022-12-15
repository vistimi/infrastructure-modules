ARG VARIANT=alpine:3.16
ARG RUNNER=workflow
ARG ALPINE_VARIANT=alpine:3.16
ARG GO_ALPINE_VARIANT=golang:1.19.0-alpine
ARG PYTHON_ALPINE_VARIANT=python:3.10.5-alpine

#-------------------------
#       BUILDER
#-------------------------
FROM ${ALPINE_VARIANT} as builder-alpine

RUN apk update
RUN apk add -q --no-cache git zip gzip tar dpkg make wget

# rover
RUN mkdir rover && cd rover && wget -q https://github.com/im2nguyen/rover/releases/download/v0.3.3/rover_0.3.3_linux_amd64.zip \
    && unzip rover_0.3.3_linux_amd64.zip && mv rover_v0.3.3 /usr/local/bin/rover \
    && chmod +rx /usr/local/bin/rover && cd .. && rm -R rover

# terraform
RUN wget -q https://releases.hashicorp.com/terraform/1.3.6/terraform_1.3.6_linux_amd64.zip \
    && unzip terraform_1.3.6_linux_amd64.zip && mv terraform /usr/local/bin/terraform \
    && chmod +rx /usr/local/bin/terraform && rm terraform_1.3.6_linux_amd64.zip

# terragrunt
RUN wget -q https://github.com/gruntwork-io/terragrunt/releases/download/v0.42.4/terragrunt_linux_amd64 \
    && mv terragrunt_linux_amd64 /usr/local/bin/terragrunt \
    && chmod +rx /usr/local/bin/terragrunt

# cloud-nuke
RUN wget -q https://github.com/gruntwork-io/cloud-nuke/releases/download/v0.21.0/cloud-nuke_linux_amd64 \
    && mv cloud-nuke_linux_amd64 /usr/local/bin/cloud-nuke \
    && chmod +rx /usr/local/bin/cloud-nuke

# # Pre-commit
# RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# RUN sudo apt install pre-commit \
#     && sudo npm install -g @commitlint/cli \
#     pre-commit install --hook-type commit-msg

#-------------------------
#    PYTHON BUILDER
#-------------------------
FROM ${PYTHON_ALPINE_VARIANT} as builder-alpine-python

ARG AWS_CLI_VERSION=2.9.0
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake
RUN git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git

WORKDIR aws-cli
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

#-------------------------
#    GOLANG BUILDER
#-------------------------
FROM ${GO_ALPINE_VARIANT} as builder-alpine-go

RUN apk update
RUN apk add -q --no-cache git zip gzip tar dpkg make wget

# inframap
RUN git clone https://github.com/cycloidio/inframap && cd inframap && go mod download && make build \
    && mv inframap /usr/local/bin/inframap  \
    && chmod +rx /usr/local/bin/inframap && cd .. && rm -R inframap

#-------------------------
#    BUILDER FINAL
#-------------------------
FROM ${VARIANT} as builder-final

RUN apk update
RUN apk add -q --no-cache make gcc libc-dev

# RUN rc-service docker start
# # RUN sudo usermod -aG docker $USER && newgrp docker
# RUN docker ps

# Golang
COPY --from=builder-alpine-go /usr/local/go/ /usr/local/go/
COPY --from=builder-alpine-go /go/ /go/
# ENV GOROOT /go
ENV GOPATH /go
ENV PATH /usr/local/go/bin:$PATH
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH
RUN go version

# cloud-nuke
COPY --from=builder-alpine /usr/local/bin/cloud-nuke /usr/local/bin/cloud-nuke
RUN cloud-nuke --version

# rover
RUN apk add -q --no-cache chromium
COPY --from=builder-alpine /usr/local/bin/rover /usr/local/bin/rover
RUN rover --version
# EXPOSE 9000

# terraform
COPY --from=builder-alpine /usr/local/bin/terraform /usr/local/bin/terraform
RUN terraform --version

# terratest
COPY --from=builder-alpine /usr/local/bin/terragrunt /usr/local/bin/terragrunt
RUN terragrunt --version

# inframap
RUN apk add -q --no-cache graphviz
COPY --from=builder-alpine-go /usr/local/bin/inframap /usr/local/bin/inframap
RUN inframap version

# tflint
COPY --from=ghcr.io/terraform-linters/tflint:v0.43.0 /usr/local/bin/tflint /usr/local/bin/tflint
RUN tflint --version && tflint --init

# aws cli, possible to create an other stage and build there
COPY --from=builder-alpine-python /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder-alpine-python /aws-cli-bin/ /usr/local/bin/
RUN aws --version

# github cli
RUN apk add --no-cache -q github-cli

RUN    go install github.com/cweill/gotests/gotests@latest \
    && go install github.com/fatih/gomodifytags@latest \
    && go install github.com/josharian/impl@latest \
    && go install github.com/haya14busa/goplay/cmd/goplay@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install honnef.co/go/tools/cmd/staticcheck@latest \
    && go install golang.org/x/tools/gopls@latest




#                    ---> runner-${ALPINE_VARIANT}           ---
#                   /                                            \
#  builder-final ---                                              ---> runner
#                   \                                            /
#                    ---> runner-${DEVCONTAINTER_VARIANT}    ---

#-------------------------
#    RUNNER ALPINE
#-------------------------
FROM builder-final AS runner-workflow

# COPY go.mod go.sum ./
# RUN go mod download && go mod verify

# COPY . .

# WORKDIR /workspace/infrasucture-modules

# CMD ["make help"]

#-------------------------
#    RUNNER DEVCONTAINER
#-------------------------
FROM builder-final AS runner-devcontainer

#-------------------------
#       RUNNER
#-------------------------
FROM runner-${RUNNER} AS runner
RUN echo runner=$RUNNER