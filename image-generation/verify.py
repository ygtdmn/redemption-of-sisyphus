"""Generate the image for a single seed and check its hash.

Use this to confirm a setup reproduces gen.py's output bit for bit before
spending days searching seeds:

    python verify.py --seed 42 --expect <keccak256 of the 32x32 png>

The generation and hashing functions and the prompt are taken from gen.py
itself (its search loop is not run), so this exercises exactly the same code.
"""

import argparse
import ast
import hashlib
import os
import platform
import sys
from pathlib import Path

GEN_PY = Path(__file__).with_name("gen.py")


def load_gen_py():
    """Execute gen.py's imports, constants and functions, but not its main loop."""
    tree = ast.parse(GEN_PY.read_text(), filename=str(GEN_PY))
    keep = []
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef)):
            keep.append(node)
        elif isinstance(node, ast.Assign) and any(
            isinstance(t, ast.Name) and t.id in ("TARGET_HASH", "prompt") for t in node.targets
        ):
            keep.append(node)
    namespace = {"__name__": "gen"}
    exec(compile(ast.Module(body=keep, type_ignores=[]), str(GEN_PY), "exec"), namespace)
    return namespace


def cpu_model():
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or "unknown"


def describe_environment(torch):
    import diffusers
    import PIL
    import transformers

    print("environment:")
    print(f"  python        {platform.python_version()} ({platform.machine()})")
    print(f"  torch         {torch.__version__}")
    print(f"  diffusers     {diffusers.__version__}")
    print(f"  transformers  {transformers.__version__}")
    print(f"  pillow        {PIL.__version__}")
    print(f"  cpu           {cpu_model()}")
    print(f"  cpu isa       {torch.backends.cpu.get_cpu_capability()}")
    print(f"  torch threads {torch.get_num_threads()}")
    for var in ("ATEN_CPU_CAPABILITY", "DNNL_MAX_CPU_ISA", "MKL_ENABLE_INSTRUCTIONS", "OMP_NUM_THREADS"):
        if var in os.environ:
            print(f"  {var}={os.environ[var]}")
    manifest = Path(os.environ.get("MODEL_MANIFEST", "/opt/model-manifest.txt"))
    if manifest.exists():
        revision = next(
            (l.split(": ", 1)[1] for l in manifest.read_text().splitlines() if l.startswith("revision: ")),
            "unknown",
        )
        print(f"  model rev     {revision}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--seed", type=int, required=True, help="seed to generate (0 to 2^32-1)")
    parser.add_argument("--expect", help="expected keccak256 of the 32x32 png; exit 1 on mismatch")
    parser.add_argument("--out", default="output", help="directory to save the images in (default: output)")
    args = parser.parse_args()

    gen = load_gen_py()
    torch = gen["torch"]
    Image = gen["Image"]

    describe_environment(torch)
    print(f"seed: {args.seed}")
    print("generating (25 steps on cpu, this takes a few minutes)...")

    # Same steps as one iteration of gen.py's search loop
    image = gen["generate_image"](gen["prompt"], args.seed)
    downscaled = image.resize((32, 32), resample=Image.NEAREST)
    image_hash = gen["calculate_image_sha256"](downscaled)

    os.makedirs(args.out, exist_ok=True)
    image.save(os.path.join(args.out, f"{args.seed}.png"))
    downscaled.save(os.path.join(args.out, f"{args.seed}_32x32.png"))

    # Hash of the raw pixels, independent of PNG encoding. If this matches a reference
    # but the keccak256 does not, the difference is in Pillow/zlib, not in the model.
    pixels_sha256 = hashlib.sha256(image.tobytes()).hexdigest()

    print("result:")
    print(f"  keccak256(32x32 png)   {image_hash}")
    print(f"  sha256(512x512 pixels) {pixels_sha256}")
    if image_hash == gen["TARGET_HASH"]:
        print("  this seed matches the artwork's TARGET_HASH")

    if args.expect:
        if image_hash == args.expect.lower().removeprefix("0x"):
            print("PASS: hash matches the expected value, this setup reproduces the reference output")
        else:
            print(f"FAIL: expected {args.expect}")
            sys.exit(1)


if __name__ == "__main__":
    main()
