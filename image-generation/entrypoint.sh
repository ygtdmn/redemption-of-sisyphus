#!/bin/sh
# Pin the CPU settings the reference output was generated with. The output
# depends on both the instruction set and the thread count, so these override
# anything passed in with -e.
set -e

# 16 threads, the count the reference was generated with
export OMP_NUM_THREADS=16
export MKL_NUM_THREADS=16

# AVX2 for torch, oneDNN and MKL alike, so AVX512 CPUs take the same code paths
export ATEN_CPU_CAPABILITY=avx2
export DNNL_MAX_CPU_ISA=AVX2
export MKL_ENABLE_INSTRUCTIONS=AVX2

# torch silently falls back to slower kernels when the CPU lacks AVX2 (or FMA,
# which its AVX2 kernels also need), which would give different output
python - <<'EOF'
import sys

import torch

isa = torch.backends.cpu.get_cpu_capability()
if isa != "AVX2":
    sys.exit(
        f"error: this CPU cannot run torch's AVX2 kernels (torch reports {isa!r}).\n"
        "The reference output was generated with AVX2, so this machine cannot reproduce it."
    )
EOF

exec "$@"
