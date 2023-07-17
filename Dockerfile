ARG AWS_ECR_REGISTRY=496882976578.dkr.ecr.us-west-1.amazonaws.com
ARG AWS_ECR_REPOSITORY=infrastructure-modules-trunk-bin
ARG VARIANT=$AWS_ECR_REGISTRY/$AWS_ECR_REPOSITORY

FROM ${VARIANT}

ARG USERNAME=user
ARG USER_UID=1001
ARG USER_GID=$USER_UID
USER $USERNAME

WORKDIR /home/$USERNAME

COPY --chown=$USERNAME:$USER_GID . .

RUN echo Date::; date; echo ;echo Files in home::; ls -l
RUN echo Changes in the past 2h::; find ./ -not -path '*/.*' -type f -mmin -120 -mmin +1