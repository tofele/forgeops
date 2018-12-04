# Environment settings for the deployment
# Using shell parameter expansion to parse the yaml file

# Set the URL_PREFIX and DOMAIN from common.yaml and
# remove any leading spaces
while read line
do
    if [[ "$line" =~ ^fqdn:.*$ ]]; then
    	FQDN=${line#fqdn:}
    	FQDN=${FQDN// /}
    fi

    if [[ "$line" =~ ^domain:.*$ ]]; then
    	DOMAIN=${line#domain:}
    	DOMAIN=${DOMAIN// /}
    fi
done < common.yaml

# The URL prefix for openam service
# You can override by just providing a string here
URL_PREFIX="${FQDN%%.*}"

#REPO="forgerock-docker-public.bintray.io/forgerock"
REPO="eu.gcr.io/swissid-cloud"
TAG="6.5.0"
PULL_POLICY="Always"

# k8s namespace to deploy in
NAMESPACE="eng"

# Top level domain. Do not include the leading "."
# You can override by just providing a string here
DOMAIN="${DOMAIN/\./}"

# The components to deploy
# Note the opendj stores are aliased as configstore,
# userstore, ctstore - but they all use the opendj chart
COMPONENTS=(frconfig configstore userstore ctsstore openam amster)
