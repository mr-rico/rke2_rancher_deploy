#!/bin/bash
#
#
###############################################################################
# Script Name : 2_binary_check.sh
# Description : Install hauler if it is not already installed. 
# Usage       : ./2_binary_chedk.sh or called from ./0_rke2_deploy.sh
# Author      : Rico Randall
# Created     : 2025-06-16
# Last Updated: 2025-07-13
# Version     : 1.09
# License     : MIT
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges.
###############################################################################

source vars.sh

# Checks to see if the hauler binary and hauler store files are in the /tmp directory
check_files() {
  echo -e "\n\033[0;32mChecking if binary and content files are present in ${FILE_STORE}\033[0m"
  for FILE in "${ALL_FILES[@]}"; do
    if [ ! -f "${WORKING_DIR}/${FILE}" ]; then
      echo "❌ Required file '${FILE}' not found in ${WORKING_DIR}. Exiting."
      exit 1
    fi
  done
  echo "All files are present in ${WORKING_DIR}."
}

# Checks to see if the hauler dir and hauler store directories exists. Creates them if they do not exist.
check_dir() {
  echo -e "\n\033[0;32mChecking for the presence of the working directory\033[0m"
  if [ ! -d "${HAULER_STORE}" ]; then
      echo "Directory ${HAULER_STORE} does not exist. Creating it now..."
      mkdir -p "${HAULER_STORE}" "${FILE_STORE}"
      if [ $? -eq 0 ]; then
          echo "Directory ${HAULER_STORE} created successfully."
      else
          echo "Failed to create directory ${HAULER_STORE}." >&2
          exit 1
      fi
  else
      echo "Directory ${HAULER_STORE} already exists."
  fi
}

# Checks to see if hauler is installed and if it is not then install it.
check_hauler() {
  echo -e "\n\033[0;32mChecking if hauler is installed on the system\033[0m"
  if ! command -v hauler >/dev/null 2>&1; then
    echo "❌ Hauler is NOT installed or not in the system PATH."
    tar -C ${HAULER_EXEC_PATH} -xf "${WORKING_DIR}/hauler_1.1.1_linux_amd64.tar.gz" hauler
    chmod 755 "${HAULER_EXEC_PATH}/hauler"
    chown "$(id -u):$(id -g)" "${HAULER_EXEC_PATH}/hauler"
    if ! grep -q ". <(hauler completion bash)" ~/.bashrc; then echo ". <(hauler completion bash)" >> ~/.bashrc; fi
    source ~/.bashrc
    hash -r
  fi
}

# Ensures hauler is in the right execution path.
check_path() {
  echo "Checking if hauler is in the correct execution path"
  ACTUAL_PATH=$(command -v hauler)
  if [ "${ACTUAL_PATH}" != "${HAULER_EXEC_PATH}/hauler" ]; then
    echo "⚠️ Hauler is installed but not at the expected path."
    echo "   Found at: ${ACTUAL_PATH}"
    echo "   Expected: ${HAULER_EXEC_PATH}/hauler"
    echo " Moving to ${HAULER_EXEC_PATH}"
    mv "${ACTUAL_PATH}" "${HAULER_EXEC_PATH}/"
  fi

  echo "✅ Hauler is installed at the correct location: ${HAULER_EXEC_PATH}"
  hauler version | head
}


main() {
	check_files
	check_dir
	check_hauler
	check_path	
}

main "$@"
