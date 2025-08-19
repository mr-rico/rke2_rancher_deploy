#!/bin/bash
#
#
###############################################################################
# Script Name : 0_rke2_deploy.sh
# Description : Deploys all scripts needed to deploy a functioning RKE2 Cluster
#               with 3 control nodes.
#               - Establish SSH connectivity
#               - Install hauler binaries and setup file server and image registy
#               - Initialize cluster and join other nodes to cluster
# Usage       : ./0_rke2_deploy.sh 
# Author      : Rico Randall
# Created     : 2025-06-16
# Last Updated: 2025-07-23
# Version     : 1.08
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges and can be customize through changing 
#               the contents of the vars.sh file
###############################################################################

source ./vars.sh

./1_gen_ssh_keys.sh
sleep 5
./2_binary_check.sh
sleep 5
./3_configure_hauler.sh
sleep 5
./4_start_services.sh
sleep 5
./5_cluster_init.sh
sleep 5
./6_cluster_join.sh
sleep 5
./7_mgmt_tools.sh
sleep 5
./8_install_rancher.sh
