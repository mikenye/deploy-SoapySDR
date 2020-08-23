#!/usr/bin/env bash
#shellcheck shell=bash

# Define appname (for logging)
APPNAME="deploy-SoapySDR"

# Define transient packages, required only during build
TRANS_PACKAGES=()
TRANS_PACKAGES+=('build-essential')
TRANS_PACKAGES+=('ca-certificates')
TRANS_PACKAGES+=('cmake')
TRANS_PACKAGES+=('git')

# Define permanent packages, required for operation
PERMA_PACKAGES=()


# Define loggiing fuction
LIGHTBLUE='\033[1;34m'
NOCOLOR='\033[0m'
function logger() {
    echo -e "${LIGHTBLUE}[$APPNAME] $1${NOCOLOR}"
}

# ===== Main Script =====

logger "deployment started"

# Do we need to run apt-get update?
if [[ -d /var/lib/apt/lists ]]; then
  if [[ $(ls -l /var/lib/apt/lists | wc -l) -le 1 ]]; then
    logger "apt-get update required"
    apt-get update
  fi
fi

# Determine which packages need installing
PKGS_TO_INSTALL=()
PKGS_TO_REMOVE=()
for PKG in "${TRANS_PACKAGES[@]}"; do
  if dpkg -s "$PKG" > /dev/null 2>&1; then
    logger "package '$PKG' already exists"
  else
    logger "package '$PKG' will be temporarily installed"
    PKGS_TO_INSTALL+=($PKG)
    PKGS_TO_REMOVE+=($PKG)
  fi
done
for PKG in "${PERMA_PACKAGES[@]}"; do
  if dpkg -s "$PKG" > /dev/null 2>&1; then
    logger "package '$PKG' already exists"
  else
    logger "package '$PKG' will be installed"
    PKGS_TO_INSTALL+=($PKG)
  fi
done

# Install packages
logger "installing packages"
apt-get install --no-install-recommends -y ${PKGS_TO_INSTALL[@]}

# Clone SoapySDR repo
logger "cloning SoapySDR repo"
git clone https://github.com/pothosware/SoapySDR.git /src/SoapySDR
pushd /src/SoapySDR

# If BRANCH_SOAPYSDR is not already set, use the latest branch
if [[ -z "$BRANCH_SOAPYSDR" ]]; then
    BRANCH_SOAPYSDR="$(git tag --sort='-creatordate' | head -1)"
    logger "BRANCH_SOAPYSDR not set, will build branch/tag '$BRANCH_SOAPYSDR'"
else
    logger "will build branch/tag '$BRANCH_SOAPYSDR'"
fi


# Check out requested version
git checkout "${BRANCH_SOAPYSDR}"
echo "SoapySDR ${BRANCH_SOAPYSDR}" >> /VERSIONS

# Build
logger "building SoapySDR"
mkdir -p /src/SoapySDR/build
pushd /src/SoapySDR/build
cmake -Wno-dev ..
make all
make install
ldconfig
popd && popd

# Test
logger "Testing SoapySDRUtil"
if SoapySDRUtil --info > /dev/null 2>&1; then
    logger "SoapySDRUtil OK"
else
    SoapySDRUtil --info
    exit 1
fi

# Clean up
logger "Cleaning up"
apt-get remove -y ${PKGS_TO_REMOVE[@]}
apt-get autoremove -y
rm -rf /src/SoapySDR

logger "Finished"
