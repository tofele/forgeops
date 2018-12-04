#!/usr/bin/env bash
# Copyright (c) 2016-2017 ForgeRock AS. Use of this source code is subject to the
# Common Development and Distribution License (CDDL) that can be found in the LICENSE file

# See https://blog.openshift.com/getting-started-helm-openshift/

#source "$(dirname $0)/../etc/oc-env.cfg"
source "${BASH_SOURCE%/*}/../etc/oc-env.cfg"

# get version of local helm client to allow deploying tiller of same version
HELM_VERSION=$( helm version --client --template "{{.Client.SemVer}}")

oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" -p HELM_VERSION=${HELM_VERSION} | oc apply -n ${TILLER_NAMESPACE} -f -

oc rollout status deployment tiller

helm init --client-only
