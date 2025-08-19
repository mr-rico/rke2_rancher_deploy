#!/bin/bash
#
#
###############################################################################
# Script Name : 3_configure_hauler.sh
# Description : Setup and configure hauler file server and registry services
# Usage       : ./3_configure_hauler.sh or called from ./0_rke2_deploy.sh
# Author      : Rico Randall
# Created     : 2025-06-16
# Last Updated: 2025-07-13
# Version     : 1.09
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges.
###############################################################################

source ./vars.sh

# Load the hauler store so files and images can be served to clients. Timer prevents the script from proceeding until this loading is complete and it takes approx 10 - 12 minutes.
ELAPSED_TIME=0
echo -e "\n\033[0;32mLoading the hauler store\033[0m"
hauler -d ${HAULER_DIR} store -s ${HAULER_STORE} load "${WORKING_DIR}/${HAULER_CONTENT}" &
JOB_PID=$!
echo "⏳ Waiting for hauler store to finish loading (PID: $JOB_PID)..."
# Loop until the process ends
while kill -0 "$JOB_PID" 2>/dev/null; do
  ((ELAPSED_TIME++))
  sleep 60
  echo -e "\033[0;33m${ELAPSED_TIME} minutes have passed...\033[0m"
done

while [ ! -x /opt/hauler-dir/cosign ]; do
  echo -e "\033[0;33m⏳ Waiting for /opt/hauler-dir/cosign to be executable...\033[0m"
  sleep 5
done
echo "✅ /opt/hauler-dir/cosign is now available and executable!"

echo -e "\033[0;32m✅ Finished loading!\033[0;32m\n"

# Create the systemd file for the hauler file server service to have persistence across reboots
echo -e "\n\033[0;32mCreating the service file for the Hauler Fileserver\033[0;32m\n"
cat <<EOF | sudo tee "/etc/systemd/system/hauler-fileserver.service" >/dev/null
[Unit]
Description=Hauler Fileserver
After=network.target

[Service]
ExecStart=${HAULER_EXEC_PATH}/hauler store serve fileserver --haulerdir ${HAULER_DIR} --store ${HAULER_STORE}
WorkingDirectory=${HAULER_DIR}
Restart=always
RestartSec=60
User=root

[Install]
WantedBy=multi-user.target
EOF

# Create the systemd file for the hauler registry service to have persistence across reboots
echo -e "\n\033[0;32mCreating the service file for the Hauler OCI Registry\033[0m"
cat <<EOF | sudo tee "/etc/systemd/system/hauler-registry.service" >/dev/null
[Unit]
Description=Hauler OCI Registry
After=network.target

[Service]
ExecStart=${HAULER_EXEC_PATH}/hauler store serve registry --haulerdir ${HAULER_DIR} --store ${HAULER_STORE}
WorkingDirectory=${HAULER_DIR}
Restart=always
RestartSec=60
User=root

[Install]
WantedBy=multi-user.target
EOF

