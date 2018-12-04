#!/bin/bash

BATCH_DIR=$(cd $(dirname "$0")/..; pwd)
source ${BATCH_DIR}/opendj/lib-header-opendj.sh

LOGS=${opendjExtractTargetPath}/logs
mkdir -p $LOGS

# Note: $LOGS/replication is always overwritten below. Splunk will already have it picked up within a few seconds and then it is not required anymore.

$binDir/dsreplication status --adminUID admin --adminPasswordFile "$passwordFile" --hostname localhost --port $adminConnectorPort --trustAll --no-prompt --script-friendly | sed -e "s/^/`date` ReplicationStatus /g" > $LOGS/replication
