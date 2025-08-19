#!/bin/bash
#
#
###############################################################################
# File Name   : vars.sh
# Description : Holds all variables that determine how the clusters are
#               deployed and configured
# Usage       : file is sourced by the following scripts 0_rke2_deploy.sh,
# 		1_gen_ssh_keys.sh, 2_binary_check.sh, 3_ configure_hauler.sh,
# 		4_start_services.sh, 5_cluster_init.sh, 6_cluster_join,sh, 
# 		and 7_mgmt_tools.sh
# Author      : Rico Randall
# Created     : 2025-06-16
# Last Updated: 2025-07-13
# Version     : 1.08
# Notes       : Modify the script's behaviors by chaning the contents of this
# 		file.
###############################################################################
# Variables for the bash script

# These should be changed to reflect the IPs of the RKE2 nodes. This variable will be used to create the host file if needed.
ALL_IPS=("192.168.0.101" \
         "192.168.0.102" \
         "192.168.0.103" \
         "" \
         )

# This variable contains the hostnames of the RKE2 nodes. It will be used for the majority of the deployment and configuration. Ensure the primary node is first in the list as it will be used as the   hauler server providing file server and registry services for all nodes.
RKE2_NODES=("rke2-control-1" \
            "rke2-control-2" \
            "rke2-control-3" \
            )

# This variable could be phased out but is retained to keep the code scaleable
HAULER_SVR="${RKE2_NODES[0]}"
# The doamain name should reflect the DNS services or host file configuration of nodes.
DOMAIN="lab"

HAULER_BINARY="hauler_1.1.1_linux_amd64.tar.gz"
HAULER_CONTENT="haul-3.0.0.tar.zst"

HAULER_DIR="/opt/hauler-dir"
HAULER_STORE="/opt/hauler-dir/store"
HAULER_EXEC_PATH="/usr/local/bin"

WORKING_DIR="/root"
FILE_STORE="${WORKING_DIR}/tmp"
REMOTE_USER="root"
SSH_KEY="$HOME/.ssh/id_rsa"

# This should be changed if the hauler server ceases to be run by the primary RKE2 node Currently there seems to be an issue preventing the initialization of the cluster when the primary is not the image registry.
HAULER_REGISTRY="localhost"
URL="http://${HAULER_SVR}:8080/"

ALL_FILES=("${HAULER_CONTENT}" "${HAULER_BINARY}")


# Rancher Variables
CERTMANAGER_VERSION="1.17.0"
RANCHER_CARBIDE_VERSION="2.10.2"
FILE_DIR="/home/rancher/extracted_files"
RANCHER_DOMAIN_NAME="rancher.${DOMAIN}"
RANCHER_URL="http://${RANCHER_DOMAIN_NAME}/"
REGISTRY_DNS="${HAULER_SVR}.${DOMAIN}"
RANCHER_PASSPHRASE="UGuessedIt!"
