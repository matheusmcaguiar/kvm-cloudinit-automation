#!/bin/bash
# 0-bootstrap_host.sh
# Version: 1.0
# Script to install dependencies before running vm_create.sh
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
# Must be run via sudo
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
	echo ">>## [ERROR] This script must be run with sudo." >&2
	exit 1
fi

# Distribution detection
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo ">>## [ERROR] Unable to detect distribution (/etc/os-release not present)." >&2
    exit 1
fi

################################################################################
# INTERNAL CONFIGURATION
################################################################################
set -u

################################################################################
# EXECUTION
################################################################################
echo ">>## Initializing Host KVM dependencies provisioning..."
echo ">>## Detected System: ${NAME} (${DISTRO})"

#-------------------------------------------------------------------------------
# DEBIAN / UBUNTU Installation Flow
#-------------------------------------------------------------------------------
if [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" ]]; then
    echo ">>## Updating APT repositories..."
    apt-get update -y

    echo ">>## Installing dependencies (DEB)..."
    apt-get install -y \
	curl \
        gettext-base \
        openssl \
        libvirt-daemon-system \
        libvirt-clients \
        virtinst \
        guestfs-tools \
	qemu-utils

#-------------------------------------------------------------------------------
# REDHAT / ROCKY / FEDORA / ALMA Installation Flow
#-------------------------------------------------------------------------------
elif [[ "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "fedora" || "$DISTRO" == "almalinux" ]]; then
    
    echo ">>## Updating DNF cache..."
    dnf makecache

    echo ">>## Installing dependencies (RPM)..."
    dnf install -y \
	curl \
        gettext \
	openssl \
	libvirt \
        virt-install \
	guestfs-tools

#-------------------------------------------------------------------------------
# Not supported distro
#-------------------------------------------------------------------------------
else
    echo ">>## [ERROR] '${DISTRO}' is not natively supported by this script." >&2
    exit 1
fi

#-------------------------------------------------------------------------------
# Service libvirtd
#-------------------------------------------------------------------------------
echo ">>## Ensuring Libvirt service is running..."
systemctl enable --now libvirtd

#-------------------------------------------------------------------------------
# Status message
#-------------------------------------------------------------------------------
echo ">>## Everything looks good! Host ${DISTRO} is ready to run vm_create.sh!"
