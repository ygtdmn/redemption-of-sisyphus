# Redemption of Sisyphus

A fully on-chain, instruction-based AI artwork. The artwork stores its generation instructions (prompt, model,
parameters) on-chain instead of storing the final image. Anyone can claim it by finding the correct Stable Diffusion
seed whose output matches a keccak256 hash stored in the smart contract.

## How It Works

- The smart contract stores a keccak256 hash of a specific 32x32 downscaled PNG image
- The on-chain metadata displays the prompt, model parameters, and generation instructions
- Anyone can run the generation script to brute-force seeds (0 to 4,294,967,295) until finding one that matches
- Submitting the correct image bytes to the `claimArtwork()` function transfers the token to the caller and reveals the
  artwork on-chain permanently

## How to Claim the Artwork

### Step 1: Setup Environment

Install Python 3.12 and the required packages:

```bash
cd image-generation
pip install -r requirements.txt
```

Or use the Docker image, which pins the exact Python, package wheels and model weights and includes a script to check
your setup against a known seed. See [image-generation/README.md](image-generation/README.md).

### Step 2: Run the Generation Script

Navigate to the image generation directory and run the script:

```bash
python gen.py
```

**What it does:**

- Loads Stable Diffusion v1.5 on CPU (for cross-device determinism)
- Generates images with random seeds from the range 0 to 2³²-1
- Downscales each image to 32x32 using nearest-neighbor resampling
- Calculates keccak256 hash of the PNG bytes
- Compares against the target hash stored in the contract
- Caches tested seeds in `seed_cache.json` to avoid retesting
- Saves outputs to `image-generation/output/` directory

**Note:** This is computationally intensive. On a single CPU, finding the correct seed could take anywhere from days to
years, or you might get lucky. Collaborative efforts or future hardware improvements may reduce this time significantly.

### Step 3: Claim the Token

Once you've found the matching seed, convert the 32x32 PNG to binary format:

```bash
xxd -b image-generation/output/<found_seed>_32x32.png | cut -d' ' -f2-7 | tr -d ' \n'
```

Then call the `claimArtwork(bytes calldata image)` function on the **RedemptionOfSisyphusRenderer** contract via
[Etherscan](https://etherscan.io/address/0x65B32f2AC1D1EcCb85c051B62eDA8aF49C3798fB#writeContract) or your preferred
web3 interface, passing the binary image data as the argument.

Upon successful claim:

- The ERC1155 token transfers from the renderer contract to your address
- The revealed image is stored on-chain
- The metadata updates to display the revealed artwork
- A `TokenClaimed` event is emitted

## Generation Parameters

| Parameter             | Value                                                                                                                                              |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Model**             | `sd-legacy/stable-diffusion-v1-5`                                                                                                                  |
| **Prompt**            | `a man stands on a misty mountain at dawn, a stone rolling down the hill. oil painting style, soft brushstrokes, muted tones, romantic landscape.` |
| **Seed Range**        | 0 - 4,294,967,295 (2³² possibilities)                                                                                                              |
| **Inference Steps**   | 25                                                                                                                                                 |
| **Guidance Scale**    | 7.5                                                                                                                                                |
| **Output Resolution** | 32x32 (downscaled from original using nearest-neighbor)                                                                                            |
| **Target Hash**       | `d792017ba77e5e122a434c6166283484f00b6e8f247310425ea36ae22e1899af`                                                                                 |
| **Device**            | CPU (for deterministic cross-platform results)                                                                                                     |

## Deployed Contracts

| Chain    | Contract                     | Address                                                                                                               |
| -------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Ethereum | RedemptionOfSisyphus (Main)  | [0xD54F497C555A2eC589b5f567014D807ec314b22F](https://etherscan.io/address/0xD54F497C555A2eC589b5f567014D807ec314b22F) |
| Ethereum | RedemptionOfSisyphusRenderer | [0x65B32f2AC1D1EcCb85c051B62eDA8aF49C3798fB](https://etherscan.io/address/0x65B32f2AC1D1EcCb85c051B62eDA8aF49C3798fB) |
| Ethereum | Ephemera (Manifold ERC1155)  | [0xCb337152b6181683010D07e3f00e7508cd348BC7](https://etherscan.io/address/0xCb337152b6181683010D07e3f00e7508cd348BC7) |

**View on OpenSea:**
[Redemption of Sisyphus](https://opensea.io/assets/ethereum/0xcb337152b6181683010d07e3f00e7508cd348bc7/6)

## Verification Hashes

For reproducible environment setup, verify these SHA256 hashes:

```
Python-3.12.11.tgz:
sha256: 7b8d59af8216044d2313de8120bfc2cc00a9bd2e542f15795e1d616c51faf3d6

torch-2.7.1-cp312-cp312-manylinux_2_28_x86_64.whl:
sha256: c33360cfc2edd976c2633b3b66c769bdcbbf0e0b6550606d188431c81e7dd1fc

diffusers-0.34.0-py3-none-any.whl:
sha256: b0f642cd57756357bad5d23fe95b61f2e6e30321c93f1302cca6d832a01e6d33

transformers-4.54.0-py3-none-any.whl:
sha256: c96e607f848625965b76c677b2c2576f2c7b7097c1c5292b281919d90675a25e

accelerate-1.9.0-py3-none-any.whl:
sha256: c24739a97ade1d54af4549a65f8b6b046adc87e2b3e4d6c66516e32c53d5a8f1

pillow-11.3.0-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl:
sha256: 676b2815362456b5b3216b4fd5bd89d362100dc6f4945154ff172e206a22c024

stable-diffusion-v1-5/v1-5-pruned-emaonly.safetensors:
sha256: 6ce0161689b3853acaa03779ec93eafe75a02f4ced659bee03f50797806fa2fa
```

## Architecture

### Smart Contracts

- **RedemptionOfSisyphus.sol**: ERC1155 Creator Extension that handles minting and metadata delegation to Manifold's
  Ephemera contract
- **RedemptionOfSisyphusRenderer.sol**: Handles all metadata rendering and the claiming mechanism. Stores the image
  hash, pre-reveal assets (SVG/HTML), and revealed image data

## Learn More

- **X Thread**: [Original announcement](https://x.com/YigitDuman/status/1950304888396603449)

## License

MIT
