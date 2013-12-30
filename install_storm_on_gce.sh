#!/usr/bin/env bash

################################################################################
# Launches a simple Storm cluster on GCE with the following layout:
#
#   192.158.31.148 zk
#   23.251.128.67  nimbus
#   192.158.29.83  slave1
#   23.251.128.41  slave2
#
# See http://datadventures.markbox.io/2013/12/29/storm-on-gce for details. 
#
# Author: Michael Hausenblas
# Licence: Public Domain


################################################################################
# Configuration
#
GCE_PROJECT=storm-simple
GCE_ZONE=europe-west1-a
MACHINE_TYPE=n1-highmem-2
VM_IMAGE=projects/centos-cloud/global/images/centos-6-v20131120

STORM_ZK_NODE=zk
STORM_NIMBUS_NODE=nimbus
STORM_SLAVE_NODES=( slave1 slave2 )

ZK_SETUP_SCRIPT=setup/zk_setup.sh
NIMBUS_SETUP_SCRIPT=setup/nimbus_setup.sh
SLAVE_SETUP_SCRIPT=setup/slave_setup.sh


################################################################################
# Generic set up of node
function setup_node() {
  gcutil --project=$GCE_PROJECT \
        addinstance $1 \
        --zone=$GCE_ZONE \
        --machine_type=$MACHINE_TYPE \
        --image=$VM_IMAGE \
        --metadata_from_file=startup-script:$2 \
        --service_account_scopes=storage-rw \
        --wait_until_running
}

################################################################################
# Set up ZooKeeper node
function setup_zk() {
  setup_node $STORM_ZK_NODE $ZK_SETUP_SCRIPT
  echo "Provisioning of ZK node done."
  sleep 3
  gcutil --project=storm-simple addfirewall zk --description="Allow ZK" --allowed=":2181" --print_json
  echo "Added firewall for port 2181."
  echo "ZK node ready."  
}

################################################################################
# Set up Nimbus node
function setup_nimbus() {
  setup_node $STORM_NIMBUS_NODE $NIMBUS_SETUP_SCRIPT
  echo "Provisioning of Nimbus node done."
  sleep 3
  gcutil --project=storm-simple addfirewall nimbus --description="Allow Nimbus" --allowed=":6627" --print_json
  gcutil --project=storm-simple addfirewall nimbusui --description="Allow Nimbus UI" --allowed=":8080" --print_json
  echo "Added firewalls for port 6627 and 8080."
  echo "Nimbus node ready."  
}

################################################################################
# Set up Slave node
function setup_slave() {
  setup_node $1 $SLAVE_SETUP_SCRIPT
  echo "Provisioning of "$1" done, Slave node ready."
}

################################################################################
# The main script
#
echo "Launching Storm cluster with 1xZK, 1xNimbus and "${#STORM_SLAVE_NODES[@]}"xSlave nodes, started at "`date`

## todo: check if already deployed

## todo: accept project ID as CLI parameter and default to GCE_PROJECT

setup_zk
setup_nimbus
for slave in "${STORM_SLAVE_NODES[@]}"
do
  setup_slave $slave
done

gcutil --project=storm-simple addfirewall supervisor1 --description="Allow Supervisor" --allowed=":6700" --print_json
gcutil --project=storm-simple addfirewall supervisor2 --description="Allow Supervisor" --allowed=":6701" --print_json
echo "Added firewalls for port 6700 and 6701."

echo "Launch Storm cluster done at "`date`