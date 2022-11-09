# use bash not sh
SHELL := /bin/bash

# Latest commit hash
GIT_SHA=$(shell git rev-parse HEAD)

# If working copy has changes, append `-dirty` to hash
GIT_DIFF=$(shell git diff -s --exit-code || echo "-dirty")
GIT_REV=$(GIT_SHA)$(GIT_DIFF)

BUILD_TIMESTAMP=$(shell date '+%F_%H:%M:%S')

ROOT_PATH=/workspaces/infrastructure-modules/
VPC_PATH=/workspaces/infrastructure-modules/modules/vpc

.PHONY: all
test-prepare:
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
		cd ${VPC_PATH}; \
		terragrunt init; \
		terragrunt apply -auto-approve; \
	fi;
check:
	# make test-prepare; \
	cd ${ROOT_PATH}; \
	declare -A PROVS=( ["NL"]=10 ["PE"]=11 ["NS"]=12 ["NB"]=13 \
        ["QC"]=24 ["ON"]=35 ["MB"]=46 ["SK"]=47 ["AB"]=48 \
        ["BC"]=59 ["YK"]=60 ["NT"]=61 ["NU"]=62 )\
	printf ${#PROVS[@]}; \
	declare -A VARS; \
	vars[0]="VPC_ID"; \
	vars[1]="VPC_SG_ID"; \
	vars[2]="VPC_PRIVATE_SUBNETS"; \
	vars[3]="VPC_PUBLIC_SUBNETS"; \
	echo ${vars}; \
	declare -a procs; \
	procs[0]="terraform -chdir=${VPC_PATH} output -raw vpc_id"; \
	procs[1]="terraform -chdir=${VPC_PATH} output -raw default_security_group_id"; \
	procs[2]="terraform -chdir=${VPC_PATH} output -raw private_subnets"; \
	procs[3]="terraform -chdir=${VPC_PATH} output -raw public_subnets"; \
	num_procs=${#procs[@]}; \
	echo "num_procs = ${num_procs}"; \
	for i in ${num_procs}; do \
		./procs[${i}] & \
		pids[${i}]=$!; \
	done; \
	for i in ${pids}; do \
		wait ${pid[${i}]}; \
		export vars[${i}]="$?"; \
	done; \
	echo "All $num_procs processes have ended."; \
	export VPC_ID=$(terraform -chdir=${VPC_PATH} output -raw vpc_id); \
	echo "vpc_id=${VPC_ID}"; \
	echo "default_security_group_id=${VPC_SG_ID}"; \
	echo "private_subnets=${VPC_PRIVATE_SUBNETS}"; \
	echo "public_subnets=${VPC_PUBLIC_SUBNETS}"; \
test:
	go test -p 1 -v -cover ./...;
# nuke-all:
# 	cloud-nuke aws
# nuke-old:
# 	cloud-nuke aws --older-than 4h

