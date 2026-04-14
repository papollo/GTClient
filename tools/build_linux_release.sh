#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_PRESET="linux-release"
BUILD_DIR="${REPO_ROOT}/build/${BUILD_PRESET}"
BUILD_OUTPUT_DIR="${BUILD_DIR}/bin"
TARGET_DIR="${TARGET_DIR:-/home/apollo/Linux_GT_release}"
VCPKG_ROOT_DEFAULT="/home/apollo/vcpkg"

if [ -z "${VCPKG_ROOT:-}" ]; then
  export VCPKG_ROOT="${VCPKG_ROOT_DEFAULT}"
fi

# Some older vcpkg ports in this project baseline are not compatible with
# downloaded CMake 4.x. Force vcpkg to use the system cmake/ninja toolchain.
export VCPKG_FORCE_SYSTEM_BINARIES=1

if [ ! -d "${VCPKG_ROOT}" ]; then
  echo "VCPKG_ROOT does not exist: ${VCPKG_ROOT}" >&2
  echo "Set VCPKG_ROOT to your vcpkg checkout before running this script." >&2
  exit 1
fi

echo "Repo root: ${REPO_ROOT}"
echo "Using VCPKG_ROOT: ${VCPKG_ROOT}"
echo "Using system binaries for vcpkg: ${VCPKG_FORCE_SYSTEM_BINARIES}"
echo "Target package directory: ${TARGET_DIR}"

cd "${REPO_ROOT}"

cmake --preset "${BUILD_PRESET}" -DTOGGLE_BIN_FOLDER=ON
cmake --build --preset "${BUILD_PRESET}" --target otclient

if [ ! -d "${BUILD_OUTPUT_DIR}" ]; then
  echo "Expected build output directory was not created: ${BUILD_OUTPUT_DIR}" >&2
  exit 1
fi

rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

cp -a "${REPO_ROOT}/mods" "${TARGET_DIR}/"
cp -a "${REPO_ROOT}/modules" "${TARGET_DIR}/"
cp -a "${REPO_ROOT}/data" "${TARGET_DIR}/"
cp -a "${REPO_ROOT}/init.lua" "${TARGET_DIR}/"
cp -a "${REPO_ROOT}/otclientrc.lua" "${TARGET_DIR}/"
cp -a "${REPO_ROOT}/cacert.pem" "${TARGET_DIR}/"
cp -a "${BUILD_OUTPUT_DIR}/." "${TARGET_DIR}/"

echo "Linux release staged at: ${TARGET_DIR}"
