# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.245.2/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version (use ubuntu-22.04 or ubuntu-18.04 on local arm64/Apple Silicon): ubuntu-22.04, ubuntu-20.04, ubuntu-18.04
ARG VARIANT="jammy"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>

# Pre-commit
# RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# RUN sudo apt install pre-commit \
#     && sudo npm install -g @commitlint/cli \
#     pre-commit install --hook-type commit-msg

# cloud-nuke
RUN sudo wget https://github.com/gruntwork-io/cloud-nuke/releases/download/v0.21.0/cloud-nuke_linux_amd64 \
    && sudo mv cloud-nuke_linux_amd64 /usr/local/bin/cloud-nuke \
    && sudo chmod +rx /usr/local/bin/cloud-nuke

# dot graphviz
RUN sudo apt-get update && sudo apt-get install graphviz -y
RUN git clone https://github.com/cycloidio/inframap && cd inframap && go mod download && make build && cd ..
RUN export PATH="~/inframap:$PATH"