#!/usr/bin/env bash

# Script to deploy Cert-Manager into ${NAMESPACE}.
# Run ./deploy-cert-manager.sh .

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

# Set tiller namespace for helm
export TILLER_NAMESPACE=${NAMESPACE}

# Decrypt encoded service account
./decrypt.sh ../etc/cert-manager/cert-manager.json

# Create secret so the Cluster Issuer can gain access to CloudDNS
kubectl create secret generic clouddns --from-file=../etc/cert-manager/cert-manager.json -n ${NAMESPACE}

# Check that tiller is running
while true;
do
  STATUS=$(kubectl get pod -n ${NAMESPACE} | grep tiller | awk '{ print $3 }')
  # kubectl get pods returns an empty string if the cluster is not available
  if [ -z ${STATUS} ]
  then
    echo "The cluster is temporarily unavailable..."
  else
    if [ ${STATUS} == "Running" ]
    then
      echo "The tiller pod is available..."
      break
    else
      echo "The tiller pod is not available..."
    fi
  fi
  sleep 5
done

# Deploy Cert Manager Helm chart
helm upgrade -i cert-manager --namespace ${NAMESPACE} stable/cert-manager

# Check that cert-manager is up before deploying the cluster-issuer
while true;
do
  STATUS=$(kubectl get pod -n ${NAMESPACE} | grep cert-manager | awk '{ print $3 }')
  # kubectl get pods returns an empty string if the cluster is not available
  if [ -z ${STATUS} ]
  then
    echo "The cluster is temporarily unavailable..."
  else
    if [ ${STATUS} == "Running" ]
    then
      echo "The cert-manager pod is available..."
      break
    else
      echo "The cert-manager pod is not available..."
    fi
  fi
  sleep 5
done

# Allow time for operator to be deployed so CRDs are recognized
sleep 5

# Deploy Cluster Issuer
kubectl create -f ../etc/cert-manager/cluster-issuer.yaml -n ${NAMESPACE}

# Delete decrypted service account
rm -f ../etc/cert-manager/cert-manager.json || true
