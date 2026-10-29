#!/bin/bash
# main.sh
# Version: 1.0
# Main Script for kvm-cloudinit-automation
# Author: Matheus Aguiar <matheus.mc.aguiar@gmail.com>
#
#-------------------------------------------------------------------------------
# Prerequisites:
# 	- Root privileges (sudo)
#
################################################################################
# INTERNAL CONFIGURATION
################################################################################
set -eo pipefail

################################################################################
# INITIAL VALIDATIONS
################################################################################
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
	echo ">>## [ERROR] This script must be run with sudo." >&2
	exit 1
fi

################################################################################
# EXECUTION
################################################################################
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

echo "============================================================="
echo ">>## Running bootstrap_host.sh for kvm-cloudinit-automation..."
echo "============================================================="
"$SCRIPT_DIR/1-provisioning/0-bootstrap_host.sh"

echo "============================================================="
echo ">>## Provisioning Virtual Machines (vm_create.sh)..."
echo "============================================================="
"$SCRIPT_DIR/1-provisioning/vm_create.sh"
