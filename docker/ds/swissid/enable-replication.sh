#!/bin/bash

BATCH_DIR=$(cd $(dirname "$0")/..; pwd)
source ${BATCH_DIR}/opendj/lib-header-opendj.sh
source ${BATCH_DIR}/opendj/lib-shared-opendj.sh

replicateStores
