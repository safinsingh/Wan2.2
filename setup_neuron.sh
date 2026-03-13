#!/bin/bash
set -euo pipefail

# ── Clean slate ──────────────────────────────────────────────
rm -rf .venv

# ── Python 3.11 (neuronx-cc has no cp312 wheels) ────────────
if ! command -v python3.11 &>/dev/null; then
    echo "Installing Python 3.11..."
    sudo yum install -y python3.11 python3.11-pip
fi

# ── Create venv ──────────────────────────────────────────────
python3.11 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip

# ── Step 1: CPU-only PyTorch (no NVIDIA junk) ────────────────
# --index-url points ONLY at the PyTorch CPU wheel index,
# so torch + torchvision come without CUDA/NVIDIA libs.
pip install torch torchvision \
    --index-url https://download.pytorch.org/whl/cpu

# ── Step 2: Neuron SDK ───────────────────────────────────────
# torch is already installed from step 1 and satisfies
# torch-neuronx's "torch==2.X.*" requirement, so pip won't
# re-download the CUDA torch from PyPI.
# --extra-index-url adds the Neuron repo alongside PyPI so
# neuronx-cc's deps (islpy, etc.) can resolve from either.
pip install torch-neuronx neuronx-cc \
    --extra-index-url https://pip.repos.neuron.amazonaws.com

# ── Step 3: Guarantee Neuron-built torch-xla ─────────────────
# Step 2 may have pulled torch-xla from PyPI (generic build,
# causes GLIBC errors) instead of the Neuron repo. This forces
# the Neuron build. --index-url = Neuron repo ONLY, --no-deps
# so it doesn't drag in anything else.
pip install torch-xla --no-deps --force-reinstall \
    --index-url https://pip.repos.neuron.amazonaws.com

# ── Step 4: App dependencies ─────────────────────────────────
pip install -r requirements.txt

# ── Verify ───────────────────────────────────────────────────
python -c "
import torch
import torch_xla
import torch_xla.core.xla_model as xm
print(f'torch:     {torch.__version__}')
print(f'torch-xla: {torch_xla.__version__}')
print('Setup complete.')
"
