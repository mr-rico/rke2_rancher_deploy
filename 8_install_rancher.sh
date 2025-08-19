#!/bin/bash
#
#
###############################################################################
# Script Name : 8_install_rancher.sh
# Description : Installation of Rancher onto RKE2 cluster
# Usage       : ./8_mgmt_tools.sh or called from ./0_rke2_deploy.sh
# Author      : Rico Randall
# Created     : 2025-07-18
# Version     : 1.09
# License     : MIT
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges.
###############################################################################

source ./vars.sh

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[1;31mThis script requires root privileges. Re-running the script with sudo...\033[0m"
    exec sudo "$0" "$@"  # Re-run the script with sudo
else

# Error checking function
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31mError occurred during: $1\033[0m" >&2
        exit 1
    fi
}

# Waits for the hauler file server url to become available and start serving requests. May take up to 5 minutes.
ELAPSED_TIME=0
echo -e "\n\033[0;32mWaiting for ${URL} to become available...\033[0m"
while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${URL}")
  if [ "${STATUS}" -eq 200 ]; then
    echo "${URL} is up. Proceeding with script..."
    break
  else
    echo "${URL} is not up yet (HTTP ${STATUS})... Retrying."
    echo -e "\033[0;33m${ELAPSED_TIME} Minutes have passed.\033[0m"
    ((ELAPSED_TIME++))
    sleep 60
  fi
done

# Create 'extracted_files' directory and navigate into it
echo -e "\n\033[0;32mCreating directory: $FILE_DIR\033[0m"
mkdir -p $FILE_DIR
check_error "creating $FILE_DIR"
cd $FILE_DIR || exit
pwd

# Download cert-manager and cert-manager-crds.yaml
curl -#LO http://$HAULER_REGISTRY:8080/cert-manager-v$CERTMANAGER_VERSION.tgz
check_error "downloading cert-manager"
curl -#LO http://$HAULER_REGISTRY:8080/cert-manager-crds.yaml
check_error "downloading cert-manager-crds"

# Update aliases
echo -e "\n\033[0;32mAdding server aliases...\033[0m"
cat >> /root/.bashrc <<EOF
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=\$PATH:/var/lib/rancher/rke2/bin:/usr/local/bin
export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
EOF
source /root/.bashrc

# Copy pre-existing kubectl binary to /usr/local/bin
sudo cp /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
check_error "copying kubectl"

# Install Helm
curl -#LO http://$HAULER_REGISTRY:8080/helm.tar.gz
check_error "downloading Helm"
echo -e "\n\033[0;32mInstalling Helm...\033[0m"
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf helm.tar.gz
helm version

# Configure Cert-Manager
echo -e "\n\033[0;32mApplying cert-manager namespaces\033[0m"
kubectl apply -f -<<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    kubernetes.io/metadata.name: cert-manager
    name: cert-manager
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
EOF
check_error "applying cert-manager namespaces"

sleep 0.1

# Install cert-manager
echo -e "\n\n\033[0;32mInstalling Cert-Manager...\033[0m"
kubectl apply -f cert-manager-crds.yaml
check_error "applying cert-manager-crds"
helm upgrade -i cert-manager $FILE_DIR/cert-manager-v$CERTMANAGER_VERSION.tgz --create-namespace --namespace cert-manager --version $CERTMANAGER_VERSION
check_error "installing cert-manager Helm chart"

echo -e "\n\033[0;32mPausing for 60 seconds prior to Rancher install to allow pods to initialize...\033[0m"
sleep 60

# Install Rancher
echo -e "\n\033[0;32mInstalling Rancher...\033[0m"
curl -#LO http://$HAULER_REGISTRY:8080/rancher-$RANCHER_CARBIDE_VERSION.tgz
# helm upgrade -i rancher $FILE_DIR/rancher-$RANCHER_CARBIDE_VERSION.tgz --create-namespace --namespace cattle-system --set hostname=$RANCHER_DOMAIN_NAME --set systemDefaultRegistry=$REGISTRY_DNS --version $RANCHER_CARBIDE_VERSION
# Adding in "bundledSystemCharts=true" option for STIGATRON
helm upgrade -i rancher $FILE_DIR/rancher-$RANCHER_CARBIDE_VERSION.tgz --create-namespace --namespace cattle-system --set hostname=$RANCHER_DOMAIN_NAME --set systemDefaultRegistry=$REGISTRY_DNS --set useBundledSystemChart=true --set bootstrapPassword="$(printf '%s' "${RANCHER_PASSPHRASE}")" --version $RANCHER_CARBIDE_VERSION
check_error "installing Rancher through Helm"

echo -e "\n\n\033[0;32mScript execution completed! \n\nWaiting for Rancher to fully deploy...\033[0m\n"

sleep 5

kubectl -n cattle-system rollout status deployment/rancher

fi

# ISSUE: Upgrade "rancher" failed: failed to create resource: Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": failed to call webhook: Post "https://rke2-ingress-nginx-controller-admission.kube-system.svc:443/networking/v1/ingresses?timeout=10s": tls: failed to verify certificate: x509: certificate signed by unknown authority
# 
#FIX: kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io validating-webhook-configuration
