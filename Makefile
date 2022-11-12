# use bash not sh
SHELL := /bin/bash

# special built in target name
# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
.SILENT: test-prepare-mongodb

# Latest commit hash
GIT_SHA=$(shell git rev-parse HEAD)

# If working copy has changes, append `-dirty` to hash
GIT_DIFF=$(shell git diff -s --exit-code || echo "-dirty")
GIT_REV=$(GIT_SHA)$(GIT_DIFF)

BUILD_TIMESTAMP=$(shell date '+%F_%H:%M:%S')

ROOT_PATH=/workspaces/infrastructure-modules/
VPC_PATH=${ROOT_PATH}/modules/vpc

test-prepare-vpc:
	cd ${ROOT_PATH}; \
	if [ ! -e ${VPC_PATH}/terraform.tfstate ]; then \
		echo 'locals {' > modules/account.hcl; \
		echo 'aws_account_region="${AWS_REGION}"' >> modules/account.hcl; \
		echo 'aws_account_id="${AWS_ID}"' >> modules/account.hcl; \
		echo '}' >> modules/account.hcl; \
		echo 'aws_region="${AWS_REGION}"' > modules/vpc/terraform_override.tfvars; \
		echo 'vpc_name="${AWS_PROFILE}-${AWS_REGION}-test-vpc"' >> modules/vpc/terraform_override.tfvars; \
		echo 'common_tags={Region: "${AWS_REGION}"}' >> modules/vpc/terraform_override.tfvars; \
		echo 'vpc_cidr_ipv4="1.0.0.0/16"' >> modules/vpc/terraform_override.tfvars; \
		echo 'enable_nat=true' >> modules/vpc/terraform_override.tfvars; \
		cd ${VPC_PATH}; \
		terragrunt init; \
		terragrunt apply -auto-approve; \
	fi;
test-prepare-mongodb:
	echo 'aws_access_key="${AWS_ACCESS_KEY}"' > modules/data-storage/mongodb/terraform_override.tfvars; \
	echo 'aws_secret_key="${AWS_SECRET_KEY}"' >> modules/data-storage/mongodb/terraform_override.tfvars;
test-prepare:
	make test-prepare-vpc; \
	make test-prepare-mongodb;

test:
	make clean; \
	make test-prepare; \
	# -p 1 flag to test each package sequentially using; \
	cd ${ROOT_PATH}; \
	go test -timeout 30m -p 1 -v -cover ./...; \
	make clean;

nuke-all:
	cloud-nuke aws;
nuke-region:
	cloud-nuke aws --region ${AWS_REGION} --force;
nuke-region-no-vpc:
	cloud-nuke aws --exclude-resource-type vpc --exclude-resource-type nat --region ${AWS_REGION} --force;
nuke-region-old:
	cloud-nuke aws --region ${AWS_REGION} --older-than 4h --force;

clean-vpc:
	cd ${ROOT_PATH}; \
	make nuke-region; \
	terraform -chdir=modules/vpc/ destroy -auto-approve; \
	rm /workspaces/infrastructure-modules/modules/vpc/terraform.tfstate;

