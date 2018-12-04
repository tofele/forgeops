#!/bin/bash

BATCH_DIR=$(cd $(dirname "$0")/..; pwd)
source ${BATCH_DIR}/opendj/lib-header-opendj.sh
source ${BATCH_DIR}/opendj/lib-shared-opendj.sh

echo "*** Disabling replication ..."
try "$binDir/dsreplication unconfigure --unconfigureAll --hostname localhost --port $adminConnectorPort --adminUID admin --adminPasswordFile \"$passwordFile\" --trustAll --no-prompt"

echo "*** Removing ChangelogDb ..."
rm -rf $opendjHome/changelogDb/*

echo "*** Replication Status ..."
try "$binDir/dsreplication status --hostname localhost --port $adminConnectorPort --adminUID admin --adminPasswordFile \"$passwordFile\" --trustAll --no-prompt"
