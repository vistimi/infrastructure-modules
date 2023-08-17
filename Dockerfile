ARG AWS_ECR_REGISTRY=496882976578.dkr.ecr.us-west-1.amazonaws.com
ARG AWS_ECR_REPOSITORY=infrastructure-modules-trunk-bin
ARG VARIANT=$AWS_ECR_REGISTRY/$AWS_ECR_REPOSITORY

FROM ${VARIANT}

RUN apk add --no-cache shadow sudo
ARG USERNAME=user
ARG USER_UID=1001
ENV USERNAME=$USERNAME
ENV USER_UID=$USER_UID
ENV USER_GID=$USER_UID
RUN addgroup --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # Add sudo support. Omit if you don't need to install software after connecting.
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
USER $USERNAME

# # Golang tools
# RUN go install github.com/cweill/gotests/gotests@latest \
#     && go install github.com/fatih/gomodifytags@latest \
#     && go install github.com/josharian/impl@latest \
#     && go install github.com/haya14busa/goplay/cmd/goplay@latest \
#     && go install github.com/go-delve/delve/cmd/dlv@latest \
#     && go install honnef.co/go/tools/cmd/staticcheck@latest \
#     && go install golang.org/x/tools/gopls@latest

WORKDIR /home/$USERNAME

# COPY --chown=$USERNAME:$USER_GID . .
# RUN echo Date::; date; echo ;echo Files in home::; ls -l
# RUN echo Changes in the past 2h::; find ./ -not -path '*/.*' -type f -mmin -120 -mmin +1