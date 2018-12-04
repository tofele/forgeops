#!/usr/bin/env bash
# Copyright (c) 2016-2017 ForgeRock AS. Use of this source code is subject to the
# Common Development and Distribution License (CDDL) that can be found in the LICENSE file
#
# Sample script to create a Kubernetes cluster on Google Kubernetes Engine (GKE)
# You must have the gcloud command installed and access to a GCP project.
# See https://cloud.google.com/container-engine/docs/quickstart

USAGE="Usage: $0 [-n <namespace>]"

# Output help if no arguments or -h is included
if [[ $1 == "-h" ]];then
    echo $USAGE
    echo "-n <namespace>    namespace"
    exit
fi

# Read arguments
while getopts :n: option; do
    case "${option}" in
        n) NAMESPACE=${OPTARG};;
        \?) echo "Error: Incorrect usage"
            echo $USAGE
            exit 1;;
    esac
done

NAMESPACE=${NAMESPACE:-kube-system}

# Specify binding and role for tiller based on namespace
case ${NAMESPACE} in
    kube-system)
        # only kube-system gets cluster wide privs (e.g. GKE & EKS)
        BINDING=clusterrolebinding
        ROLE=cluster-admin
        ;;
    *)
        # limited to namespace only, e.g. for sOpenshift
        BINDING=rolebinding
        ROLE=edit
        ;;
esac

# Set tiller namespace for helm
export TILLER_NAMESPACE=${NAMESPACE}

kubectl -n ${NAMESPACE} delete deployment tiller-deploy

kubectl -n ${NAMESPACE} create sa tiller
kubectl create ${BINDING} tiller --clusterrole ${ROLE} --serviceaccount=${NAMESPACE}:tiller
helm init --upgrade --wait --service-account tiller
