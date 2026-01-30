import torch
from diffusers import StableDiffusionPipeline
import random
import json
import os
from Crypto.Hash import keccak
from PIL import Image

# Target hash to find
TARGET_HASH = "d792017ba77e5e122a434c6166283484f00b6e8f247310425ea36ae22e1899af"

# Function to generate an image with a specific seed
def generate_image(prompt, seed, num_inference_steps=25, guidance_scale=7.5):
    # Enforce deterministic behavior in PyTorch
    torch.manual_seed(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

    # Load the model
    model_id = "sd-legacy/stable-diffusion-v1-5"
    pipe = StableDiffusionPipeline.from_pretrained(
        model_id,
        safety_checker=None,
        requires_safety_checker=False
    )

    # Move to CPU for cross-device consistency
    pipe = pipe.to("cpu")

    # Generate the image
    image = pipe(
        prompt=prompt,
        num_inference_steps=num_inference_steps,
        guidance_scale=guidance_scale,
    ).images[0]

    return image

# Function to load seed cache from JSON file
def load_seed_cache(cache_file="seed_cache.json"):
    if os.path.exists(cache_file):
        try:
            with open(cache_file, 'r') as f:
                return set(json.load(f))
        except (FileNotFoundError, json.JSONDecodeError):
            return set()
    return set()

# Function to save seed cache to JSON file
def save_seed_cache(seed_cache, cache_file="seed_cache.json"):
    with open(cache_file, 'w') as f:
        json.dump(list(seed_cache), f, indent=2)

# Function to calculate SHA256 of an image
def calculate_image_sha256(image):
    # Convert image to bytes
    import io
    img_byte_array = io.BytesIO()
    image.save(img_byte_array, format='PNG')
    img_bytes = img_byte_array.getvalue()

    # Calculate keccak256 of the raw image bytes (like Solidity)
    keccak256_hash = keccak.new(digest_bits=256)
    keccak256_hash.update(img_bytes)
    return keccak256_hash.hexdigest()


# Create output directory if it doesn't exist
os.makedirs("output", exist_ok=True)

# Main loop
prompt = "a man stands on a misty mountain at dawn, a stone rolling down the hill. oil painting style, soft brushstrokes, muted tones, romantic landscape."

print("Starting seed search...")
print(f"Target hash: {TARGET_HASH}")

while True:
    # Generate random seed between 0 and 2^32
    seed = random.randint(0, 2**32 - 1)

    # Load seed cache and check if seed is already used
    seed_cache = load_seed_cache()
    if seed in seed_cache:
        continue  # Retry with a new seed

    print(f"Testing seed: {seed} (Cache size: {len(seed_cache)})")

    # Generate image with the seed
    try:
        image = generate_image(prompt, seed)

        # Save the original image
        original_path = f"output/{seed}.png"
        image.save(original_path)

        # Downscale the image to 32x32 with nearest neighbor
        downscaled_image = image.resize((32, 32), resample=Image.NEAREST)

        # Save the downscaled image
        downscaled_path = f"output/{seed}_32x32.png"
        downscaled_image.save(downscaled_path)

        # Calculate SHA256 of the downscaled image
        image_hash = calculate_image_sha256(downscaled_image)

        print(f"  Generated hash: {image_hash}")

        # Check if the hash matches the target
        if image_hash == TARGET_HASH:
            print(f"TARGET HASH FOUND!")
            print(f"Matching seed: {seed}")
            print(f"Original image: {original_path}")
            print(f"Downscaled image: {downscaled_path}")
            print(f"Hash: {image_hash}")
            break  # Exit the loop
        else:
            # Save seed to cache and continue
            seed_cache.add(seed)
            save_seed_cache(seed_cache)
            print(f"  No match, seed {seed} saved to cache")

    except Exception as e:
        print(f"Error with seed {seed}: {e}")
        # Still save the seed to cache to avoid retrying it
        seed_cache.add(seed)
        save_seed_cache(seed_cache)

print("Search completed!")
