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

# ── Step 1: CPU-only PyTorch 2.9 (no NVIDIA) ────────────────
# Pin to 2.9.* — that's what torch-neuronx requires.
# --index-url = CPU wheel index only, no CUDA libs.
pip install "torch==2.9.*" "torchvision==0.24.*" \
    --index-url https://download.pytorch.org/whl/cpu

# ── Step 2: torch-neuronx (--no-deps to prevent CUDA torch) ─
pip install "torch-neuronx==2.9.0.2.12.22436+0f1dac25" --no-deps \
    --index-url https://pip.repos.neuron.amazonaws.com

# ── Step 3: neuronx-cc ──────────────────────────────────────
# Needs --extra-index-url so its deps (islpy etc.) resolve from PyPI.
pip install neuronx-cc \
    --extra-index-url https://pip.repos.neuron.amazonaws.com

# ── Step 4: torch-neuronx's other deps ──────────────────────
# We skipped deps in step 2, so install them manually.
# libneuronxla is the Neuron XLA runtime (provides _XLAC).
pip install libneuronxla \
    --extra-index-url https://pip.repos.neuron.amazonaws.com

# ── Step 5: App dependencies ────────────────────────────────
pip install -r requirements.txt

# ── Verify ───────────────────────────────────────────────────
echo ""
echo "=== Installed packages ==="
pip list | grep -iE "torch|neuron|xla|numpy"
echo ""
echo "=== Checking no NVIDIA packages ==="
pip list | grep -i nvidia && echo "WARNING: NVIDIA packages found!" || echo "Clean — no NVIDIA packages."
echo ""
python -c "
import torch
print(f'torch: {torch.__version__}')
try:
    import torch_xla
    print(f'torch-xla: {torch_xla.__version__}')
except ImportError:
    print('torch_xla: provided by libneuronxla')
import torch_xla.core.xla_model as xm
print('XLA model loaded successfully.')
"
echo ""
echo "Setup complete."
