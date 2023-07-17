SHELL:=/bin/bash
.SILENT:
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables
.ONESHELL:

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PATH_REL_AWS=module/aws
PATH_ABS_AWS=${PATH_ABS_ROOT}/${PATH_REL_AWS}
PATH_REL_AWS_MICROSERVICE=${PATH_REL_AWS}/microservice
PATH_ABS_AWS_MICROSERVICE=${PATH_ABS_ROOT}/${PATH_REL_AWS_MICROSERVICE}
PATH_ABS_AWS_ECR=${PATH_ABS_ROOT}/${PATH_REL_AWS}/container/ecr
PATH_REL_TEST_MICROSERVICE=test/microservice

OVERRIDE_EXTENSION=override
export OVERRIDE_EXTENSION
export AWS_REGION_NAME AWS_PROFILE_NAME AWS_ACCOUNT_ID AWS_ACCESS_KEY AWS_SECRET_KEY ENVIRONMENT_NAME

# error for undefined variables
check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

.PHONY: build help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all files
	terraform fmt -recursive

aws-auth:
	make -f Makefile_infra aws-auth AWS_PROFILE_NAME=${AWS_PROFILE_NAME} AWS_REGION_NAME=${AWS_REGION_NAME} AWS_ACCESS_KEY=${AWS_ACCESS_KEY} AWS_SECRET_KEY=${AWS_SECRET_KEY}
	# make -f Makefile_infra aws-auth AWS_PROFILE_NAME=${REPOSITORIES_AWS_PROFILE_NAME} AWS_REGION_NAME=${REPOSITORIES_AWS_REGION_NAME} AWS_ACCESS_KEY=${REPOSITORIES_AWS_ACCESS_KEY} AWS_SECRET_KEY=${REPOSITORIES_AWS_SECRET_KEY}
	aws configure list

test: ## Setup the test environment, run the tests and clean the environment
	make test-prepare; \
	# # p1 will not mix the logs when multiple tests are used
	# go test -timeout 30m -p 1 -v -cover ./...; \
	make clean;
test-clean-cache:
	go clean -testcache;

SCRAPER_BACKEND_BRANCH_NAME ?= trunk
SCRAPER_FRONTEND_BRANCH_NAME ?= trunk
prepare: ## Setup the test environment
	make prepare-account-aws
	make prepare-scraper-backend BRANCH_NAME=${SCRAPER_BACKEND_BRANCH_NAME}
	make prepare-scraper-frontend BRANCH_NAME=${SCRAPER_FRONTEND_BRANCH_NAME}
prepare-account-aws:
	cat <<-EOF > ${PATH_ABS_AWS}/aws_account_override.hcl 
	locals {
		aws_account_region="${AWS_REGION_NAME}"
		aws_account_name="${AWS_PROFILE_NAME}"
		aws_account_id="${AWS_ACCOUNT_ID}"
		repositories_aws_account_region="${REPOSITORIES_AWS_REGION_NAME}"
		repositories_aws_account_name="${REPOSITORIES_AWS_PROFILE_NAME}"
		repositories_aws_account_id="${REPOSITORIES_AWS_ACCOUNT_ID}"
	}
	EOF

BRANCH_NAME ?= trunk
prepare-scraper-backend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=backend)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_REL_TEST_MICROSERVICE}/${REPOSITORY_NAME})
	$(eval COMMON_NAME="")
	$(eval CLOUD_HOST=aws)
	make -f Makefile_infra gh-load-folder \
		TERRAGRUNT_CONFIG_PATH=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_CONFIG_PATH_FOLDER=config
	make prepare-scraper-backend-env \
		REPOSITORY_CONFIG_PATH=${OUTPUT_FOLDER} \
		ENV_FOLDER_PATH=${PATH_ABS_AWS_MICROSERVICE}/${REPOSITORY_NAME} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST}
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_AWS_MICROSERVICE}/${REPOSITORY_NAME}
make prepare-scraper-backend-env:
	$(eval MAKEFILE=$(shell find ${REPOSITORY_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		ENV_FOLDER_PATH=${ENV_FOLDER_PATH} \
		CONFIG_FOLDER_PATH=${REPOSITORY_CONFIG_PATH} \
		COMMON_NAME=${COMMON_NAME} \
		CLOUD_HOST=${CLOUD_HOST} \
		FLICKR_PRIVATE_KEY=123 \
		FLICKR_PUBLIC_KEY=123 \
		UNSPLASH_PRIVATE_KEY=123 \
		UNSPLASH_PUBLIC_KEY=123 \
		PEXELS_PUBLIC_KEY=123 \
		PACKAGE_NAME=scraper_backend_test \

BRANCH_NAME ?= trunk
prepare-scraper-frontend:
	$(eval GIT_NAME=github.com)
	$(eval ORGANIZATION_NAME=KookaS)
	$(eval PROJECT_NAME=scraper)
	$(eval SERVICE_NAME=frontend)
	$(eval REPOSITORY_NAME=${PROJECT_NAME}-${SERVICE_NAME})
	$(eval OUTPUT_FOLDER=${PATH_REL_TEST_MICROSERVICE}/${REPOSITORY_NAME})
	make -f Makefile_infra gh-load-folder \
		TERRAGRUNT_CONFIG_PATH=${OUTPUT_FOLDER} \
		ORGANIZATION_NAME=${ORGANIZATION_NAME} \
		REPOSITORY_NAME=${REPOSITORY_NAME} \
		BRANCH_NAME=${BRANCH_NAME} \
		REPOSITORY_CONFIG_PATH_FOLDER=config
	make prepare-scraper-frontend-env \
		REPOSITORY_CONFIG_PATH=${OUTPUT_FOLDER} \
		ENV_FOLDER_PATH=${PATH_ABS_AWS_MICROSERVICE}/${REPOSITORY_NAME}
	make -f Makefile_infra init TERRAGRUNT_CONFIG_PATH=${PATH_ABS_AWS_MICROSERVICE}/${REPOSITORY_NAME}
prepare-scraper-frontend-env:
	$(eval MAKEFILE=$(shell find ${REPOSITORY_CONFIG_PATH} -type f -name "*Makefile*"))
	make -f ${MAKEFILE} prepare \
		ENV_FOLDER_PATH=${ENV_FOLDER_PATH} \
		NEXT_PUBLIC_API_URL="http://not-needed.com" \
		PORT=$(shell yq eval '.port' ${REPOSITORY_CONFIG_PATH}/config_${OVERRIDE_EXTENSION}.yml)

clean: ## Clean the test environment
	make -f Makefile_infra nuke-region
	make -f Makefile_infra nuke-vpc
	make -f Makefile_infra nuke-global

	make -f Makefile_infra clean-task-definition
	make -f Makefile_infra clean-elb
	make -f Makefile_infra clean-ecs

	make clean-local

clean-local: ## Clean the local files and folders
	echo "Delete state files..."; for filePath in $(shell find . -type f -name "*.tfstate"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name "terraform.tfstate.backup"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*_override.*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete lock files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done;

	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terraform"); do echo $$folderPath; rm -Rf $$folderPath; done;

# TODO: actions/github-script@v6 to run nodejs in wf
# github-set-environment:
# # if ! curl -L --fail \
# # 	-H "Accept: application/vnd.github+json" \
# # 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# # 	-H "X-GitHub-Api-Version: 2022-11-28" \
# # 	https://api.github.com/repos/${REPOSITORY_NAME_OWNER}/${REPOSITORY_NAME_NAME}/environments/${GH_ENV}; then \
# # 	echo "Environemnt ${GH_ENV} is non existant and cannot be created with personal access token. Go create it on the repository ${REPOSITORY_NAME_OWNER}/${REPOSITORY_NAME_NAME}"; \
# # 	exit 10; \
# # fi
# 	echo GH_ENV=${GH_ENV}
# 	$(eval REPOSITORY_NAME_ID=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repos/${REPOSITORY_NAME_OWNER}/${REPOSITORY_NAME_NAME} | jq '.id'))
# 	echo REPOSITORY_NAME_ID=${REPOSITORY_NAME_ID}
# 	$(eval GH_PUBLIC_KEY_ID=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/secrets/public-key  | jq '.key_id'))
# 	echo GH_PUBLIC_KEY_ID=${GH_PUBLIC_KEY_ID}
# 	$(eval GH_ENV_PUBLIC_KEY=$(shell curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/secrets/public-key  | jq '.key'))
# 	echo GH_ENV_PUBLIC_KEY=${GH_ENV_PUBLIC_KEY}
# # curl -L \
# # 	-X POST \
# # 	-H "Accept: application/vnd.github+json" \
# # 	-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# # 	-H "X-GitHub-Api-Version: 2022-11-28" \
# # 	https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/variables \
# # 	-d '{"name":"MY_VAR","value":"vallll"}'
# 	make github-set-environment-secret REPOSITORY_NAME_ID=${REPOSITORY_NAME_ID} GH_ENV=${GH_ENV} GH_KEY_ID=${GH_PUBLIC_KEY_ID} GH_PUBLIC_KEY=${GH_ENV_PUBLIC_KEY} GH_SECRET_NAME=MY_SECRET GH_SECRET_VALUE=vallll
# 	# make github-set-environment-variable REPOSITORY_NAME_ID=${REPOSITORY_NAME_ID} GH_ENV=${GH_ENV} VAR_NAME=MY_VAR VAR_VALUE=vallll
# 	curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/secrets
# 	curl -L \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/variables
# github-set-environment-variable:
# 	curl -L \
# 		-X POST \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer <YOUR-TOKEN>"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/variables \
# 		-d '{"name":"${VAR_NAME}","value":"${VAR_VALUE}"}'
# github-set-environment-secret:
# 	echo set secret
# 	$(eval GH_SECRET_VALUE=$(shell echo "${GH_SECRET_VALUE}" | iconv -f utf-8))
# 	echo GH_SECRET_VALUE=${GH_SECRET_VALUE}
# 	# $(eval GH_PUBLIC_KEY=$(shell base64 -d <<< "${GH_PUBLIC_KEY}" | iconv -t utf-8))
# 	echo GH_PUBLIC_KEY=${GH_PUBLIC_KEY}

# 	gcc -o sodium_encoding sodium_encoding.c -lsodium
# 	$(eval GH_SECRET_VALUE_ENCR="$(shell ./sodium_encoding $(shell base64 -d <<< "${GH_PUBLIC_KEY}") ${GH_SECRET_VALUE})")
	
# 	echo GH_SECRET_VALUE_ENCR=${GH_SECRET_VALUE_ENCR}
# 	curl -L \
# 		-X PUT \
# 		-H "Accept: application/vnd.github+json" \
# 		-H "Authorization: Bearer ${GITHUB_TOKEN}"\
# 		-H "X-GitHub-Api-Version: 2022-11-28" \
# 		https://api.github.com/repositories/${REPOSITORY_NAME_ID}/environments/${GH_ENV}/secrets/${GH_SECRET_NAME} \
# 		-d '{"encrypted_value":${GH_SECRET_VALUE_ENCR},"key_id":"${GH_KEY_ID}"}';