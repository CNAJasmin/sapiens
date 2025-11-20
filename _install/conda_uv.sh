#!/usr/bin/env bash
set -euo pipefail

# --- Configuration -----------------------------------------------------------
CONDA_BASE="/home/${USER}/anaconda3"
ENV_NAME="sapiens_uv"         # different from the original "sapiens"
PYTHON_VERSION="3.10"

# ---------------------------------------------------------------------------
# Load conda
# ---------------------------------------------------------------------------
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
conda_env_exists() {
  conda env list | grep -q "^${1} "
}

print_green() {
  echo -e "\033[0;32m$1\033[0m"
}

print_yellow() {
  echo -e "\033[1;33m$1\033[0m"
}

# ---------------------------------------------------------------------------
# Remove existing env (if any)
# ---------------------------------------------------------------------------
if conda_env_exists "${ENV_NAME}"; then
  print_yellow "Environment '${ENV_NAME}' exists. Removing..."
  conda env remove -n "${ENV_NAME}" -y
fi

# ---------------------------------------------------------------------------
# Create and activate env
# ---------------------------------------------------------------------------
print_green "Creating environment '${ENV_NAME}' (python=${PYTHON_VERSION})..."
conda create -n "${ENV_NAME}" python="${PYTHON_VERSION}" -y

print_green "Activating environment '${ENV_NAME}'..."
conda activate "${ENV_NAME}"

# ---------------------------------------------------------------------------
# Ensure pip and uv
# ---------------------------------------------------------------------------
print_green "Ensuring pip is installed..."
conda install pip -y

if ! command -v uv >/dev/null 2>&1; then
  print_green "uv not found in this env. Installing via pip..."
  pip install uv
else
  print_green "uv already available: $(command -v uv)"
fi

# ---------------------------------------------------------------------------
# Figure out paths: SCRIPT_DIR = $SAPIENS_ROOT/_install, SAPIENS_ROOT = parent
# ---------------------------------------------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SAPIENS_ROOT="$(dirname "${SCRIPT_DIR}")"

REQ_IN="${SCRIPT_DIR}/requirements.in"
REQ_TXT="${SCRIPT_DIR}/requirements.txt"

print_green "Script directory (installer): ${SCRIPT_DIR}"
print_green "Repo root (SAPIENS_ROOT): ${SAPIENS_ROOT}"

# ---------------------------------------------------------------------------
# Check for requirements.in in _install
# ---------------------------------------------------------------------------
if [ ! -f "${REQ_IN}" ]; then
  print_yellow "requirements.in not found at ${REQ_IN}."
  print_yellow "Create ${REQ_IN} before running this script."
  exit 1
fi

# ---------------------------------------------------------------------------
# Move to repo root so editable paths like ./sapiens/... resolve correctly
# ---------------------------------------------------------------------------
cd "${SAPIENS_ROOT}" || exit 1
print_green "Changed working directory to repo root: $(pwd)"

# ---------------------------------------------------------------------------
# Generate requirements.txt via uv (in _install/)
# ---------------------------------------------------------------------------
print_green "Generating requirements.txt with uv pip compile..."
uv pip compile "${REQ_IN}" -o "${REQ_TXT}"

# ---------------------------------------------------------------------------
# Install packages via uv pip sync (using _install/requirements.txt)
# ---------------------------------------------------------------------------
print_green "Syncing environment using uv pip sync..."
uv pip sync "${REQ_TXT}"

# ---------------------------------------------------------------------------
# Install openmim + mmcv (after PyTorch)
# ---------------------------------------------------------------------------
print_green "Installing openmim..."
pip install -U openmim

print_green "Installing mmcv with mim (must come after PyTorch)..."
mim install mmcv

print_green "Environment '${ENV_NAME}' setup complete."
echo "To activate it later, run: conda activate ${ENV_NAME}"
