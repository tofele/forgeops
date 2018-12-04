#!/usr/bin/env bash
# Sample wrapper script to initialize GKE. This creates the cluster and configures Helm, the nginx ingress,
# and creates git credential secrets. Edit this for your requirements.

set -o errexit
set -o pipefail
set -o nounset

ask() {

	read -p "Should i continue (y/n)?" choice
	case "$choice" in
   		y|Y|yes|YES ) echo "yes";;
   		n|N|no|NO ) echo "no"; exit 1;;
   		* ) echo "Invalid input, Bye!"; exit 1;;
	esac
}

echo -e "WARNING: This script requires a properly provisioned Openshift account with appropriate\n\t accounts, roles, privileges, keyrings, keys etc. These pre-requisites are\n\t outlined in the DevOps Documentation. Please ensure you have completed all\n\t before proceeding."


echo ""
echo "=> Have you copied the template file etc/oc-env.template to etc/oc-env.cfg and edited to cater to your enviroment?"
ask

ocuser=`oc whoami -c`
echo ""
echo "You are authenticated and logged into Openshift as \"${ocuser}\". If this is not correct then exit this script and run \"oc login\" to login into the correct account first."
ask

#source "$(dirname $0)/../etc/oc-env.cfg"
source "${BASH_SOURCE%/*}/../etc/oc-env.cfg"

# Set the GKE Project ID to the one parsed from the cfg file
#gcloud config set project ${GKE_PROJECT_ID} 

# Now create the cluster
#./oc-create-cluster.sh

if [ $? -ne 0 ]; then
    exit 1
fi

# Add a nodepool for nfs server
#./oc-create-nodepool.sh

# Create monitoring namespace
oc create project ${OC_TILLERG_PROJECT}

# Create monitoring namespace
oc create project ${OC_MONITORING_PROJECT}

# Create the namespace parsed from cfg file and set the context
oc create project ${OC_PROJECT}
oc config set-context $(kubectl config current-context) --namespace=${OC_MONITORING_PROJECT}

# Create storage class
#./oc-create-sc.sh

# Inatilize helm by creating a rbac role first
./helm-rbac-init.sh -n ${OC_PROJECT}

# Need as sometimes tiller is not ready immediately
while :
do
    helm ls >/dev/null 2>&1
    test $? -eq 0 && break
    echo "Waiting on tiller to be ready..."
    sleep 5s
done


# Create the ingress controller
./oc-create-route.sh ${OC_ROUTE_IP}

# Deploy cert-manager
./deploy-cert-manager.sh -n ${OC_PROJECT}

# Add Prometheus
./helm-rbac-init.sh ${OC_MONITORING_PROJECT}
./deploy-prometheus.sh -n ${OC_MONITORING_PROJECT}

# Filestore is needed if you enable backups.  Uncomment the next line to create one.
./oc-create-filestore.sh
