# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets
# https://www.gnu.org/software/make/manual/html_node/Options-Summary.html

# use bash not sh
SHELL := /bin/bash

# Latest commit hash
GIT_SHA=$(shell git rev-parse HEAD)
# If working copy has changes, append `-dirty` to hash
GIT_DIFF=$(shell git diff -s --exit-code || echo "-dirty")
GIT_REV=$(GIT_SHA)$(GIT_DIFF)
BUILD_TIMESTAMP=$(shell date '+%F_%H:%M:%S')

# absolute path
ROOT_PATH=/workspaces/infrastructure-modules
VPC_PATH=${ROOT_PATH}/modules/vpc

# test
test:
	make clean; \
	make prepare; \
	# -p 1 flag to test each package sequentially; \
	cd ${ROOT_PATH}; \
	go test -timeout 30m -p 1 -v -cover ./...; \
	make clean;

# prepare
.SILENT: prepare-account prepare-modules-data-mongodb
prepare:
	make prepare-account; \
	make prepare-modules-data-mongodb; \
	make prepare-modules-vpc; 
prepare-account:
	echo 'locals {' > modules/account.hcl; \
	echo 'aws_account_region="${AWS_REGION}"' >> ${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_account_name="${AWS_PROFILE}"' >> ${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_account_id="${AWS_ID}"' >> ${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_access_key="${AWS_ACCESS_KEY}"' >> ${ROOT_PATH}/modules/account.hcl; \
	echo 'aws_secret_key="${AWS_SECRET_KEY}"' >> ${ROOT_PATH}/modules/account.hcl; \
	echo 'gh_token="${GH_TOKEN}"' >> ${ROOT_PATH}/modules/account.hcl; \
	echo '}' >> modules/account.hcl;
prepare-modules-vpc:
	# remove the state file in the vpc folder to create a new one \
	if [ ! -e ${VPC_PATH}/terraform.tfstate ]; then \
		echo 'aws_region="${AWS_REGION}"' > ${VPC_PATH}/terraform_override.tfvars; \
		echo 'vpc_name="${AWS_PROFILE,,}-${AWS_REGION}-test-vpc"' >> ${VPC_PATH}/terraform_override.tfvars; \
		echo 'common_tags={Region: "${AWS_REGION}"}' >> ${VPC_PATH}/terraform_override.tfvars; \
		echo 'vpc_cidr_ipv4="1.0.0.0/16"' >> ${VPC_PATH}/terraform_override.tfvars; \
		echo 'enable_nat=true' >> ${VPC_PATH}/terraform_override.tfvars; \
		cd ${VPC_PATH}; \
		terragrunt init; \
		terragrunt apply -auto-approve; \
	fi;
prepare-modules-data-mongodb:
	echo 'aws_access_key="${AWS_ACCESS_KEY}"' > ${ROOT_PATH}/modules/data/mongodb/terraform_override.tfvars; \
	echo 'aws_secret_key="${AWS_SECRET_KEY}"' >> ${ROOT_PATH}/modules/data/mongodb/terraform_override.tfvars;

# clean
clean:
	make clean-vpc
clean-vpc:
	cd ${ROOT_PATH}; \
	make nuke-region; \
	cd ${VPC_PATH}; \
	terragrunt destroy -auto-approve; \
	# remove the state file in the vpc folder to create a new one \
	rm /workspaces/infrastructure-modules/modules/vpc/terraform.tfstate;

# cloud-nuke
nuke-all:
	cloud-nuke aws;
nuke-region:
	cloud-nuke aws --region ${AWS_REGION} --force;
nuke-region-no-vpc-nat:
	cloud-nuke aws --exclude-resource-type vpc --exclude-resource-type nat --region ${AWS_REGION} --force;
nuke-region-old:
	cloud-nuke aws --region ${AWS_REGION} --older-than 4h --force;
