# Image generation environment

Everything `gen.py` needs, packaged as a Docker image so the output can be reproduced without hand-installing the stack.

## What is pinned

Everything follows the artwork's published hash list.

| Component       | Version                                                                                                                                      |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Platform        | `linux/amd64`, glibc 2.36 (Debian bookworm)                                                                                                  |
| Python          | 3.12.11 (official `python:3.12.11-slim-bookworm` image, pinned by digest)                                                                    |
| torch           | 2.7.1, the PyPI `manylinux_2_28_x86_64` wheel (the CUDA 12.6 build; it only runs on CPU here but needs its bundled CUDA libraries to import) |
| diffusers       | 0.34.0                                                                                                                                       |
| transformers    | 4.54.0                                                                                                                                       |
| accelerate      | 1.9.0                                                                                                                                        |
| pillow          | 11.3.0, the `manylinux_2_27_x86_64.manylinux_2_28_x86_64` wheel                                                                              |
| everything else | locked in `requirements.lock` to the versions available on 2025-07-29                                                                        |
| model           | `sd-legacy/stable-diffusion-v1-5` at commit `451f4fe16113bff5a5d2269ed5ad43b0592e9a14`                                                        |
| CPU settings    | AVX2 and 16 threads, forced by the entrypoint (see below)                                                                                    |

`requirements.lock` is installed with `pip --require-hashes`, and the five packages above carry only the sha256 from the
artwork's published hash list, so the build fails if a different wheel would be installed.

The build writes `/opt/model-manifest.txt` with the model commit and the sha256 of every weight file, so two builds can
be compared. Note that `gen.py` loads the diffusers-format folders (`unet/`, `vae/`, `text_encoder/`, ...), not the
single `v1-5-pruned-emaonly.safetensors` checkpoint.

## Build

The image is about 10 GB (about 6 GB of Python packages, mostly torch's CUDA libraries, plus about 4 GB of model
weights).

```bash
cd image-generation
docker build --platform linux/amd64 -t redemption-of-sisyphus .
```

The model is fetched at the pinned commit; `--build-arg MODEL_REVISION=<commit sha>` overrides it.

## Check your setup first

Before searching, generate one known seed and compare it with a reference hash. This takes a few minutes on CPU and
confirms that your machine produces bit-identical images:

```bash
docker run --rm -v "$PWD/work:/work" redemption-of-sisyphus \
  python /app/verify.py --seed <seed> --expect <keccak256>
```

`verify.py` runs the generation and hashing functions from `gen.py` itself (without the search loop), then prints:

- `keccak256(32x32 png)`: the value `gen.py` compares with `TARGET_HASH`
- `sha256(512x512 pixels)`: a hash of the raw pixels, independent of PNG encoding. If this matches the reference but the
  keccak256 does not, the difference comes from Pillow/zlib, not from the model
- the Python/package versions, the CPU model, torch's CPU instruction set (`cpu isa`) and thread count, any
  instruction-set or thread overrides, and the model commit

It prints `PASS` and exits 0 when the hash matches, `FAIL` and exits 1 otherwise. Without `--expect` it just prints the
hashes, which is how a reference value is produced.

### Test vector

| Seed        | keccak256(32x32 png)                                               |
| ----------- | ------------------------------------------------------------------ |
| `118517663` | `bc71f8aa0a5b39caf3746b7f78a48dc47a758ab0464d518183c1b37ddc975f73` |

```bash
docker run --rm -v "$PWD/work:/work" redemption-of-sisyphus \
  python /app/verify.py --seed 118517663 --expect bc71f8aa0a5b39caf3746b7f78a48dc47a758ab0464d518183c1b37ddc975f73
```

Produced with this image on an Intel Core i9-14900HX (AVX2, 16 threads). The same setup reproduces the artwork's
`TARGET_HASH` for the winning seed.

### CPU settings

The output depends on the CPU instruction set and the thread count: on the same machine, changing either one can change
some pixels by 1 or 2, which is invisible but enough to change the hash. The 32x32 downscale keeps only 1024 of the
262144 pixels, so different full images can still share a 32x32 hash.

So the image's entrypoint (`entrypoint.sh`) fixes them for every command, overriding anything passed with `-e`:

- 16 threads (`OMP_NUM_THREADS`, `MKL_NUM_THREADS`), whatever the number of cores
- AVX2 for torch, oneDNN and MKL (`ATEN_CPU_CAPABILITY`, `DNNL_MAX_CPU_ISA`, `MKL_ENABLE_INSTRUCTIONS`), so AVX512 CPUs
  take the same code paths as the reference

It refuses to start on a CPU that cannot run torch's AVX2 kernels. MKL may still take different code paths on AMD CPUs;
if the test vector fails on yours, compare the `cpu`, `cpu isa` and `torch threads` lines that `verify.py` prints.

## Search

```bash
docker run --rm -v "$PWD/work:/work" redemption-of-sisyphus
```

This runs `gen.py` unchanged, with the same CPU settings. Images go to `work/output/` and tested seeds to `work/seed_cache.json` on the host, so
stopping and restarting the container continues where it left off. Several containers can share the directory, though
they may occasionally test the same seed since the cache is not locked.

When the target hash is found, convert the 32x32 png on the host as described in the main README:

```bash
xxd -b work/output/<found_seed>_32x32.png | cut -d' ' -f2-7 | tr -d ' \n'
```
