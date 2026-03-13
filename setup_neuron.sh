#!/bin/bash
set -euo pipefail

if [ "${1:-}" = "--clean" ]; then
    echo "Clean install requested, removing .venv..."
    rm -rf .venv
fi

# ── Ensure python3-venv is available ─────────────────────────
sudo apt-get update -qq
sudo apt-get install -y -qq python3-venv

# ── Create venv (skip if exists) ─────────────────────────────
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip

    # CPU-only PyTorch 2.9 (no NVIDIA)
    pip install "torch==2.9.*" "torchvision==0.24.*" \
        --index-url https://download.pytorch.org/whl/cpu

    # torch-neuronx (--no-deps to prevent CUDA torch)
    pip install "torch-neuronx==2.9.0.2.12.22436+0f1dac25" --no-deps \
        --index-url https://pip.repos.neuron.amazonaws.com

    # neuronx-cc + libneuronxla
    pip install neuronx-cc libneuronxla \
        --extra-index-url https://pip.repos.neuron.amazonaws.com

    # torch-xla (--no-deps prevents CUDA torch pull)
    pip install "torch-xla==2.9.*" --no-deps

    # App dependencies
    pip install -r requirements.txt
else
    echo "Venv already exists, skipping install."
    source .venv/bin/activate
fi

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
import torch_xla
print(f'torch:     {torch.__version__}')
print(f'torch-xla: {torch_xla.__version__}')
dev = torch_xla.device()
print(f'XLA device: {dev}')
"
echo ""
echo "============================================"
echo "Setup complete. Run models with:"
echo ""
echo "  source .venv/bin/activate"
echo "  torchrun --nproc_per_node=8 generate.py ..."
echo "============================================"
