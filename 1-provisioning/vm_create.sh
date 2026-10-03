#!/bin/bash
# vm_create.sh
# Version: 1.0
# Script for sequential VM/Cloud-init provisioning.
# Author: Matheus Aguiar <matheus.mc.aguiar@gmail.com>
#
#-------------------------------------------------------------------------------
# Prerequisites:
#	- Root privileges (sudo)
#	- KVM enabled and running
#	- openssl
#	- ssh public key for the user ~/.ssh/ at the host
#	- envsubst (gettext package)
#	- libguestfs-tools
#	- virt-install
#	- virt-sysprep
#	- virsh
#	- qemu-img
#-------------------------------------------------------------------------------
# TODO:
#	- Add host option for RHEL-like with SELINUX
#
################################################################################
# INTERNAL CONFIGURATIONS
################################################################################
set -euo pipefail
export LC_ALL=C
export LIBGUESTFS_BACKEND=direct

################################################################################
# INITIAL VALIDATIONS
################################################################################
# Must be run via sudo
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
	echo ">>## [ERROR] This script must be run with sudo." >&2
	exit 1
fi
# Verify if all required commands are available
for cmd in virt-install qemu-img virt-sysprep envsubst virsh openssl; do
	if ! command -v "$cmd" &> /dev/null; then
		echo ">>## [ERROR] The required command '$cmd' is not installed." >&2
		exit 1
	fi
done

################################################################################
# LOAD EXTERNAL CONFIGURATION
################################################################################
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
CONFIG_FILE="${TEMPLATES_DIR}/cfg-vm_create.env"
CONFIG_EXAMPLE="${TEMPLATES_DIR}/cfg-vm_create.env-example"
IPS_LIST="${SCRIPT_DIR}/../2-inventory/ips_list"
REAL_USER="$SUDO_USER"
if [ ! -f "$CONFIG_FILE" ]; then
	if [ ! -f "$CONFIG_EXAMPLE" ]; then
		echo ">>## [ERROR] Configuration file not found." >&2
		echo ">>## Please create '$CONFIG_EXAMPLE' with the required variables." >&2
		exit 1
	fi
	sudo -u $REAL_USER cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
fi
# Source the configuration file safely
source "$CONFIG_FILE"
# Paths
BASE_PATH="$SCRIPT_DIR/downloads"
DISK_PATH="/var/lib/libvirt/images"
SEP="-"
DISK_BF="${NODE_TYPE}${SEP}backing_file.qcow2"
DISK_EXT=".qcow2"
# Cloud-init templates
USERDATA_BF="${TEMPLATES_DIR}/user-data-bf_template"
USERDATA_VM="${TEMPLATES_DIR}/user-data-vm_template"
METADATA_BF="${TEMPLATES_DIR}/meta-data_template"
METADATA_VM="${TEMPLATES_DIR}/meta-data_template"
NETCONF_BF="${TEMPLATES_DIR}/network-config"
NETCONF_VM="${TEMPLATES_DIR}/network-config"
# Centralized array for temporary file cleanup via trap
TMP_DIR="/tmp/"
declare -a tmp_files=()
trap 'rm -f "${tmp_files[@]}"' EXIT

################################################################################
# FUNCTIONS
################################################################################
demolish() {
	if ! virsh list --all --name | grep -q "^${NODE_TYPE}${SEP}"; then
		echo ">>## No VM '${NODE_TYPE}' found."
		return 0
	fi
	echo ">>## Destroying and undefining all ${NODE_TYPE} VMs..."
	shopt -s nullglob
	for volume in "${DISK_PATH}/${NODE_TYPE}${SEP}"[0-9]*.qcow2; do
		vm=$(basename "$volume" .qcow2)
		echo ">>## Removing $vm..."
		virsh destroy "$vm" 2>/dev/null || true
		virsh undefine "$vm" --nvram --remove-all-storage 2>/dev/null || true
	done
	shopt -u nullglob
	echo ">>## VMs cleanup completed."
}
run_virt_install() {
	local vm_name="$1"
	local disk_file="$2"
	local u_data="$3"
	local m_data="$4"
	local n_conf="$5"

	virt-install \
		--name "$vm_name" \
		--memory "$RAM" \
		--vcpus "$VCPUS" \
		--boot "$BOOT_TYPE" \
		--disk path="$disk_file",bus="$DISK_BUS" \
		--os-variant "$OS_VARIANT" \
		--network network="$NET_NAME",model="$NET_MODEL" \
		--cloud-init user-data="$u_data",meta-data="$m_data",network-config="$n_conf" \
		--graphics "$GRAPHICS" \
		--noautoconsole \
		--import
}

################################################################################
# HANDLE ARGUMENTS
################################################################################
case ${1:-} in
	"")
		;;
	"demolish")
		demolish
		exit 0
		;;
	"annihilate")
		demolish
		if [ -f "${DISK_PATH}/${DISK_BF}" ]; then
			echo ">>## Removing the backing file..."
			rm ${DISK_PATH}/${DISK_BF} || true
			echo ">>## Backing file deleted."
		else
			echo ">>## Backing file does not exist."
		fi
		exit 0
		;;
	*)
		echo ">>## [ERROR] Unexpected argument: $*"
		exit 1
		;;
esac

################################################################################
# KEY
################################################################################
REAL_USER_H=$(getent passwd "$REAL_USER" | cut -d: -f6)
# Multi-distro SSH Key Verification (ED25519, RSA, etc.)
SSH_KEY_PATH=""
for key_type in id_ed25519 id_rsa id_ecdsa; do
	if [ -f "${REAL_USER_H}/.ssh/${key_type}.pub" ]; then
		SSH_KEY_PATH="${REAL_USER_H}/.ssh/${key_type}.pub"
		break
	fi
done
if [ -z "$SSH_KEY_PATH" ]; then
	echo ">>## [ERROR] No public key found in ${REAL_USER_H}/.ssh/"
	exit 1
fi
KEY=$(tr -d '\r\n' < "$SSH_KEY_PATH")

################################################################################
# EXECUTION
################################################################################
if [ "$VM_COUNT" -gt 0 ]; then
	echo ">>## ${VM_COUNT} VMs of type '${NODE_TYPE}' will be processed."
	# Securely prompt for password
	PRE_HASH=""
	while [ -z "$PRE_HASH" ]; do
		read -s -p ">>## Enter password for configured VM user (${VM_USER}): " PRE_HASH
		echo ""
	done
	VM_PASSWORD=$(openssl passwd -6 "$PRE_HASH")
	unset PRE_HASH
fi

# ------------------------------------------------------------------------------
# 1. Backing File Preparation (Base Image)
# ------------------------------------------------------------------------------
# Checking the existence of the backing file
if [ -f "${DISK_PATH}/${DISK_BF}" ]; then
	echo ">>## ${DISK_PATH}/${DISK_BF} already exists and will be reused."
else
	# Checking the existence of the base image
	if [ -f "${BASE_PATH}/${BASE}" ]; then
		echo ">>## ${BASE_PATH}/${BASE} already exists and will be used."
	else
		echo ">>## ${BASE_PATH}/${BASE} does not exist in this project."
		echo ">>## Downloading CHECKSUM for $BASE..."
		if sudo -u "$REAL_USER" curl -L "${URL_BASE}/CHECKSUM" -o "${BASE_PATH}/${CHECK_FILE}"; then
			echo "##>> CHECKSUM download successful."
		else
			echo "##>> CHECKSUM download failed."
			exit 1
		fi
		echo ">>## Downloading Base Image for Backing File (~600MB)..."
		if sudo -u "$REAL_USER" curl -L "${URL_BASE}/${BASE}" -o "${BASE_PATH}/${BASE}"; then
			echo ">>## Download of $BASE for Backing File successful."
		else
			echo ">>## [ERROR] Download failed."
			exit 1
		fi
	fi
	echo ">>## Verifying CHECKSUM..."
	if ! (cd "$BASE_PATH" && sha256sum -c --ignore-missing "$CHECK_FILE"); then
		echo "CHECKSUM verification failed."
		exit 1
	fi
	echo ">>## Generating Base Image (Backing File)..."
	cp "${BASE_PATH}/${BASE}" "${DISK_PATH}/${DISK_BF}"
	echo ">>## Provisioning temporary VM for base adjustments..."
	HNAME="${NODE_TYPE}${SEP}bf"
	INAME="${NAME_PREFIX}${SEP}${HNAME}"
	mdata_bf_tmp=$(mktemp ${TMP_DIR}m-data-bf.XXXXXX)
	tmp_files+=("$mdata_bf_tmp")
	export HNAME INAME
	envsubst '$HNAME $INAME' < "$METADATA_BF" > "$mdata_bf_tmp"
	run_virt_install "$HNAME" "${DISK_PATH}/${DISK_BF}" "$USERDATA_BF" "$mdata_bf_tmp" "$NETCONF_BF"
	echo ">>## Waiting for temporary VM to shut down..."
	timeout=600
	elapsed=0
	while true; do
		status=$(virsh domstate "$HNAME" 2>/dev/null)
		if [ "$status" = "shut off" ]; then break; fi
		if [ "$elapsed" -ge "$timeout" ]; then
			echo ">>## [ERROR] Timeout waiting for base VM to shut down." >&2
			virsh destroy "$HNAME" 2>/dev/null || true
			virsh undefine "$HNAME" --nvram --remove-all-storage 2>/dev/null || true
			exit 1
		fi
		sleep 5
		elapsed=$((elapsed + 5))
	done
	# Cleans Backing File
	echo ">>## Running virt-sysprep on base image..."
	virt-sysprep -d "$HNAME" --operations machine-id,bash-history,logfiles,net-hostname,ssh-hostkeys,udev-persistent-net
	virsh undefine "$HNAME" --nvram
	echo ">>## Base image isolated successfully."
	if [ "${VM_COUNT}" -eq 0 ]; then
		echo ">>## VM_COUNT is 0. No VMs were created. Process finished after base image creation."
		exit 0
	fi
fi

if [ "${VM_COUNT}" -eq 0 ]; then
	echo ">>## VM_COUNT is 0. No VMs were created. Process finished."
	exit 0
fi

# ------------------------------------------------------------------------------
# 2. Final VM Creation (Linked Clones)
# ------------------------------------------------------------------------------
# Create VMs
for ((n=1; n<=VM_COUNT; n++)); do
	HNAME="${NODE_TYPE}${SEP}${n}"
	INAME="${NAME_PREFIX}${SEP}${HNAME}"
	echo ">>## Creating Linked Clone for ${HNAME}..."
	current_disk="${DISK_PATH}/${HNAME}${DISK_EXT}"
	qemu-img create -f qcow2 -F qcow2 -b "${DISK_PATH}/${DISK_BF}" "$current_disk" "${DISK_SIZE:-20G}"
	echo ">>## Provisioning VM ${HNAME}..."
	udata_vm_tmp=$(mktemp ${TMP_DIR}u-data-${HNAME}.XXXXXX)
	mdata_vm_tmp=$(mktemp ${TMP_DIR}m-data-${HNAME}.XXXXXX)
	tmp_files+=("$udata_vm_tmp" "$mdata_vm_tmp")
	export HNAME FULL_NAME INAME VM_USER VM_PASSWORD VM_GROUP KEY
	envsubst '$HNAME $FULL_NAME $VM_USER $VM_PASSWORD $VM_GROUP $KEY' < "$USERDATA_VM" > "$udata_vm_tmp"
	envsubst '$HNAME $INAME' < "$METADATA_VM" > "$mdata_vm_tmp"
	run_virt_install "$HNAME" "$current_disk" "$udata_vm_tmp" "$mdata_vm_tmp" "$NETCONF_VM"
	echo ">>## VM ${HNAME} created successfully."
done

# ------------------------------------------------------------------------------
# 3. Summary
# ------------------------------------------------------------------------------
echo ">>## Successfully created ${VM_COUNT} machine(s)."
echo ">>## Waiting for network to come up on all VMs..."
timeout=60
elapsed=0
while true; do
	if [ "$elapsed" -ge "$timeout" ]; then
		echo ">>## [ERROR] Timeout waiting for network." >&2
		for ((n=1; n<=VM_COUNT; n++)); do
			virsh destroy "${NODE_TYPE}${SEP}${n}" 2>/dev/null || true
			virsh undefine "${NODE_TYPE}${SEP}${n}" --nvram --remove-all-storage 2>/dev/null || true
		done
		exit 1
	fi
	all_up=true
	for ((n=1; n<=VM_COUNT; n++)); do
		if ! virsh domifaddr "${NODE_TYPE}${SEP}${n}" 2>/dev/null | grep -E -o -q '([0-9]+\.){3}[0-9]{1,3}'; then
		all_up=false
		break
		fi
	done

	if [ "$all_up" = true ]; then
		break
	fi
	sleep 5
	elapsed=$((elapsed + 5))
done

# List VMs with IPs
if [ -f "$IPS_LIST" ]; then
	rm "$IPS_LIST"
fi
echo "-------------------------------------------------------------"
echo ">>## Machine(s) online:"
echo "-------------------------------------------------------------"
for ((n=1; n<=VM_COUNT; n++)); do
	ip=$(virsh domifaddr "${NODE_TYPE}${SEP}${n}" | grep -E -o '([0-9]+\.){3}[0-9]{1,3}' | head -1)
	echo "${NODE_TYPE}${SEP}${n}:${ip}" | sudo -u $REAL_USER tee -a $IPS_LIST
done
echo "-------------------------------------------------------------"
