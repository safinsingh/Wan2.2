#!/bin/bash
set -euo pipefail

SHIM_DIR="$(pwd)/.neuron"
SHIM_SO="$SHIM_DIR/glibc235_shim.so"

if [ "${1:-}" = "--clean" ]; then
    echo "Clean install requested, removing .venv and .neuron..."
    rm -rf .venv "$SHIM_DIR"
fi

# ── Python 3.11 (neuronx-cc has no cp312 wheels) ────────────
if ! command -v python3.11 &>/dev/null; then
    echo "Installing Python 3.11..."
    sudo yum install -y python3.11 python3.11-pip
fi

# ── Build GLIBC 2.35 shim ───────────────────────────────────
# libneuronxla's _XLAC.so needs hypot/hypotf@GLIBC_2.35.
# Amazon Linux 2023 has GLIBC 2.34. The functions exist, just
# under an older version tag. This shim re-exports them as 2.35.
if [ ! -f "$SHIM_SO" ]; then
    mkdir -p "$SHIM_DIR"
    cat > "$SHIM_DIR/glibc235_shim.c" << 'EOF'
#include <math.h>
__asm__(".symver hypot_shim, hypot@GLIBC_2.35");
double hypot_shim(double x, double y) { return hypot(x, y); }
__asm__(".symver hypotf_shim, hypotf@GLIBC_2.35");
float hypotf_shim(float x, float y) { return hypotf(x, y); }
EOF
    gcc -shared -o "$SHIM_SO" "$SHIM_DIR/glibc235_shim.c" -lm
    rm "$SHIM_DIR/glibc235_shim.c"
    echo "Built GLIBC 2.35 shim at $SHIM_SO"
else
    echo "GLIBC 2.35 shim already exists, skipping build."
fi

# ── Create venv (skip if exists) ─────────────────────────────
if [ ! -d ".venv" ]; then
    python3.11 -m venv .venv
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
LD_PRELOAD="$SHIM_SO" python -c "
import torch
import torch_xla
import torch_xla.core.xla_model as xm
print(f'torch:     {torch.__version__}')
print(f'torch-xla: {torch_xla.__version__}')
print('XLA model loaded successfully.')
"
echo ""
echo "============================================"
echo "Setup complete. Run models with:"
echo ""
echo "  source .venv/bin/activate"
echo "  export LD_PRELOAD=$SHIM_SO"
echo "  torchrun --nproc_per_node=8 generate.py ..."
echo "============================================"
