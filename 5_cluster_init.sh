#!/bin/bash
#
#
###############################################################################
# Script Name : 5_cluster_init.sh
# Description : Initializes the RKE2 cluster
# Usage       : ./5_cluster_init.sh or called from ./0_rke2_deploy.sh
# Author      : Rico Randall
# Created     : 2025-06-16
# Version     : 1.09
# License     : MIT
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges.
###############################################################################

source ./vars.sh

# Create the registries.yaml file that points all nodes to the hauler server as the private image registry
echo -e "\n\033[0;32mCreating the registries.yaml file and placing it under ${FILE_STORE}\033[0m"
cat <<EOF > "${FILE_STORE}/registries.yaml"
#configs:
#  "${HAULER_SVR}:5000":
#  "*"
#    tls:
#      insecure_skip_verify: true
mirrors:
  docker.io:
    endpoint:
      - "http://${HAULER_SVR}:5000"
  quay.io:
    endpoint:
      - "http://${HAULER_SVR}:5000"
  "*":
    endpoint:
      - "http://${HAULER_SVR}:5000"
EOF

# Creates the config.yaml file for the cluster initialization node
echo -e "\n\033[0;32mCreating the config.yaml file for the initialization node under ${FILE_STORE}\033[0m"
cat <<EOF | sudo tee "${FILE_STORE}/init_config.yaml" >/dev/null
# Force the nodes to connect to a private registry
system-default-registry: "${HAULER_REGISTRY}:5000"

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

# Create the directory for the yaml files and pushes the registy.yaml file to all nodes while the config.yaml is only pushed to the cluster initialization node.
echo -e "\n\033[0;32mCreating the /etc/rancher/rke2 directories and copying the registries.yaml and config.yaml files over to remote servers\033[0m"
for HOST in "${RKE2_NODES[@]}"; do
  ssh -i "${SSH_KEY}" "${REMOTE_USER}@${HOST}" 'mkdir -p /etc/rancher/rke2'
  scp -i "${SSH_KEY}" "${FILE_STORE}/registries.yaml" "${REMOTE_USER}@${HOST}:/etc/rancher/rke2/registries.yaml"
  if [ "${HOST}" = "${HAULER_SVR}" ]; then
    scp -i "${SSH_KEY}" "${FILE_STORE}/init_config.yaml" "${REMOTE_USER}@${HOST}:/etc/rancher/rke2/config.yaml"
  fi
done

# Waits for the hauler file server url to become available and start serving requests. This takes around 5 minutes.
ELAPSED_TIME=0
echo -e "\n\033[0;32mWaiting for ${URL} to become available...\033[0m"
while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${URL}")
  if [ "${STATUS}" -eq 200 ]; then
    echo -e "\n\033[0;32m${URL} is up. Proceeding with script...\033[0m"
    break
  else
    echo "${URL} is not up yet (HTTP ${STATUS})... Retrying."
    sleep 60
    ((ELAPSED_TIME++))
    echo -e "\033[0;33m${ELAPSED_TIME} Minutes have passed.\033[0m"

  fi
done

# Create the bash script that configures the firewall and install rpm files for rke2 services.
echo -e "\n\033[0;32mCreating the bash script rpm_install.sh under ${FILE_STORE} to execute installations and configure firewall rules on RKE2 nodes.\033[0m"
cat <<EOF > "${FILE_STORE}/rpm_install.sh"
echo -e "\033[0;33mConfigure RKE2 firewall rules\033[0m"
firewall-cmd --permanent --add-port=6443/tcp 
firewall-cmd --permanent --add-port=9345/tcp 
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=8472/udp
firewall-cmd --permanent --add-port=179/tcp
firewall-cmd --permanent --add-port=4789/udp
# Cilium ports
firewall-cmd --permanent --add-port=4240/tcp
firewall-cmd --permanent --add-masquerade
echo -e "\033[0;33mConfigure Hauler firewall rules\033[0m"
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=5000/tcp
# Reload firewall services
firewall-cmd --reload
echo -e "\033[0;33mInstalling packages\033[0m"
rpm -ivh http://${HAULER_SVR}:8080/container-selinux.noarch.rpm
rpm -ivh http://${HAULER_SVR}:8080/rancher-selinux.noarch.rpm
rpm -ivh http://${HAULER_SVR}:8080/rke2-selinux.noarch.rpm
rpm -ivh http://${HAULER_SVR}:8080/rke2-common.rpm
rpm -ivh http://${HAULER_SVR}:8080/rke2-server.rpm
EOF

# Makes the script executable, distributes it to all nodes, and initiates the execution of the script on all nodes.
echo "Making the script executable, copying it over to the remote systems, and executing it on the remote systems."
chmod +x "${FILE_STORE}/rpm_install.sh"

# Copy rpm_install.sh file over to remote servers and execute
for HOST in "${RKE2_NODES[@]}"; do
  echo "Copying rpm_install.sh file to ${HOST}..."
  scp -i "${SSH_KEY}" "${FILE_STORE}/rpm_install.sh" "${REMOTE_USER}@${HOST}:~"
  echo -e "\n\033[0;32mInstalling rpm_install.sh file on ${HOST}...\033[0m"
  ssh -i "${SSH_KEY}" "${REMOTE_USER}@${HOST}" "bash ~/rpm_install.sh"
done

# Starts the rke2-server service on the initialization node to create the RKE2 cluster
echo -e "\n\033[0;32mStarting the rke2-server service on ${RKE2_NODES[0]} to create the cluster\033[0m"
ssh -i "${SSH_KEY}" "${REMOTE_USER}@${RKE2_NODES[0]}" 'systemctl enable --now rke2-server'

