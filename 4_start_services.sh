#!/bin/bash
#
#
###############################################################################
# Last Updated: 2025-07-13
# Script Name : 4_start_services.sh
# Description : Start services for the hauler file server and image registry
# Usage       : ./4_start_services.sh or called from ./0_rke2_deploy.sh
# Author      : Rico Randall
# Created     : 2025-06-16
# Last Updated: 2025-07-13
# Version     : 1.05
# License     : MIT
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges.
###############################################################################

source ./vars.sh

# Reconfigure SELinux for hauler services to operate
echo -e "\n\033[0;32mConfiguring SELinux\033[0m"
chcon -t bin_t "${HAULER_EXEC_PATH}/hauler"
chcon -R -t var_lib_t "${HAULER_STORE}"

echo -e "\n\033[0;32mStarting systemd services\033[0m"
systemctl daemon-reexec
systemctl daemon-reload

# Start the hauler file server and registry services
systemctl enable --now hauler-fileserver.service
systemctl enable --now hauler-registry.service
sleep 5
