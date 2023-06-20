ARG AWS_REGION=us-west-1
ARG AWS_ACCOUNT_ID=401582117818
ARG AWS_ECR_REPOSITORY=kookas-infrastructure-modules-master-bin
ARG VARIANT=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$AWS_ECR_REPOSITORY

FROM ${VARIANT}

ARG USERNAME=user
ARG USER_UID=1001
ARG USER_GID=$USER_UID

WORKDIR /home/$USERNAME

COPY --chown=$USERNAME:$USER_GID . .

RUN echo Date::; date; echo ;echo Files in home::; ls -l
RUN echo Changes in the past 2h::; find ./ -not -path '*/.*' -type f -mmin -120 -mmin +1