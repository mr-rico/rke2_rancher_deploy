#!/bin/bash
#
#
###############################################################################
# Script Name : 7_mgmt_tools.sh
# Description : Setup management tools for RKE2 cluster
# Usage       : ./7_mgmt_tools.sh or called from ./0_rke2_deploy.sh
# Author      : Rico Randall
# Created     : 2025-06-16
# Version     : 1.09
# License     : MIT
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges.
###############################################################################

source ./vars.sh

echo -e "\n\033[0;32mWaiting for cluster to finish initialization...\033[0m"
ELAPSED_TIME=0
while ! systemctl is-active --quiet rke2-server; do 
	sleep 60
	((ELAPSED_TIME++))
    echo -e "\033[0;33m${ELAPSED_TIME} minutes have passed...\033[0m"
done
echo -e "\n\033[0;32mCluster is initialized!\033[0m"

mkdir ~/.kube
cp /var/lib/rancher/rke2/bin/kubectl ${HAULER_EXEC_PATH}/
cp /etc/rancher/rke2/rke2.yaml ~/.kube/config

# Set up bash completion for kubectl
if ! grep -q "source <(kubectl completion bash)" ~/.bashrc; then echo "source <(kubectl completion bash)" >> ~/.bashrc; fi; source ~/.bashrc

kubectl get nodes
