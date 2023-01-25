#!/bin/sh

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)

   KEY_LENGTH=${#KEY}
   VALUE="${ARGUMENT:$KEY_LENGTH+1}"

   export "$KEY"="$VALUE"
done

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets/${GH_SECRET_KEY} \
  -f encrypted_value=${GH_SECRET_VALUE} \
 -f key_id=$(gh api -H "Accept: application/vnd.github+json" /repositories/${GH_REPO_ID}/environments/${GH_ENV}/secrets/public-key --jq .key_id)


