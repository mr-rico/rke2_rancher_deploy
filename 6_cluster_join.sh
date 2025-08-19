#!/bin/bash
#
#
###############################################################################
# Script Name : 6_cluster_join.sh
# Description : Joins the remaining nodes to the RKE2 cluster
# Usage       : ./6_cluster_join.sh or called from ./0_rke2_deploy.sh
# Author      : Rico Randall
# Created     : 2025-06-16
# Version     : 1.09
# License     : MIT
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges.
###############################################################################

source ./vars.sh

# Creates the config.yaml file for the nodes joining the initialized cluster
echo -e "\n\033[0;32mCreating the config.yaml file for the nodes joining the cluster under ${FILE_STORE}\033[0m"
cat <<EOF | sudo tee "${FILE_STORE}/join_config.yaml" >/dev/null
# The server and token values are the only changes from the initial control node and the additional ones
server: https://${RKE2_NODES[0]}.${DOMAIN}:9345

# Shared token across control plane nodes (HA)
token: $(ssh -i "${SSH_KEY}" "${REMOTE_USER}@${RKE2_NODES[0]}" 'cat /var/lib/rancher/rke2/server/node-token')

# Enable cilium CNI instead of canal
cni: cilium

# This disables canal (the default CNI)
disable:
  - rke2-canal

# If you have no kube-vip or LB, can also disable coredns:
# disable:
#   - rke2-coredns

# Permissions for kubeconfig
write-kubeconfig-mode: "0644"
selinux: true
EOF

# Copy the config.yaml file over to the nodes joining the initialized cluster
echo -e "\n\033[0;32mCopy the config.yaml file over to remote servers\033[0m"
for HOST in "${RKE2_NODES[@]}"; do
  if [ "${HOST}" != "${RKE2_NODES[0]}" ]; then
    scp -i "${SSH_KEY}" "${FILE_STORE}/join_config.yaml" "${REMOTE_USER}@${HOST}:/etc/rancher/rke2/config.yaml"
  fi
done

# Start the rke2-server service on all nodes joining the initializated cluster so they may join it.
echo -e "\n\033[0;32mStarting the rke2-server service on remaining nodes so they are added to the cluster\033[0m"
for HOST in "${RKE2_NODES[@]}"; do
  if [ "${HOST}" != "${RKE2_NODES[0]}" ]; then
    ssh -i "${SSH_KEY}" "${REMOTE_USER}@${HOST}" 'systemctl enable --now rke2-server'
  fi
done


