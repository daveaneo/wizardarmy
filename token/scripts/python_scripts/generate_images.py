#!/usr/bin/env python3

import os
import random
from PIL import Image # pip install Pillow
import shutil

# ======================
# Configuration
# ======================

# Absolute path to the directory containing the folders of images.
DIR_PATH = '/home/david/Documents/Wizard_Army/art_temp'



def clear_directory(dir_path):
    """Remove all files from a directory but keep the directory itself."""
    for filename in os.listdir(dir_path):
        file_path = os.path.join(dir_path, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            print(f'Failed to delete {file_path}. Reason: {e}')


def combine_images(images, output_height=300):
    """
    Combine and layer a list of images.

    Args:
        images (list): A list of PIL Image objects to be combined.
        output_height (int, optional): The desired height for the combined image. Default is 300.

    Returns:
        PIL.Image.Image: A combined image from the input images.
    """
    # Resize images while maintaining aspect ratio.
    # This ensures each image has the desired height while width is adjusted accordingly.
    resized_images = [img.resize((int((output_height / img.height) * img.width), output_height)) for img in images]

    # Calculate the total width for the combined image. It will be the maximum width among the resized images.
    total_width = max(img.width for img in resized_images)

    # Create a blank canvas with the calculated width and desired height.
    combined_img = Image.new('RGBA', (total_width, output_height), (255, 255, 255, 0))

    # Layer each image onto the canvas.
    for img in resized_images:
        combined_img.paste(img, ((total_width - img.width) // 2, 0), img)

    return combined_img

def main(sample_size=None):
    """
    Main function to layer and combine images from different folders.

    Args:
        sample_size (int, optional): If provided, a random sample of this size will be generated instead of creating all permutations. Default is None.
    """

    # Clean previous permutations
    output_folder = os.path.join(DIR_PATH, 'permutations')
    clear_directory(output_folder)

    # List and sort all the folders in the provided directory.
    # List and sort all the folders in the provided directory, excluding the 'permutations' folder.
    folders = sorted([os.path.join(DIR_PATH, d) for d in os.listdir(DIR_PATH) if
                      os.path.isdir(os.path.join(DIR_PATH, d)) and d.isnumeric() ])

    # Load images from each folder.
    # This creates a dictionary where the key is the folder path and the value is a list of Image objects.
    folder_images = {}
    for folder in folders:
        images = [Image.open(os.path.join(folder, img_file)) for img_file in os.listdir(folder) if img_file.endswith(('.png', '.jpg', '.jpeg'))]
        folder_images[folder] = images

    # print(f'folders')
    # for f in folders:
    #     print(f)
    # exit(0)

    # Generate permutations of images.
    if sample_size:
        # If sampling, create a list of random permutations.
        permutations = []
        for _ in range(sample_size):
            permutation = [random.choice(folder_images[folder]) for folder in folders]
            permutations.append(permutation)
    else:
        # If not sampling, create all possible permutations of images from the different folders.
        from itertools import product
        permutations = list(product(*folder_images.values()))

    # Ensure there's a 'permutations' folder to save the results.
    output_folder = os.path.join(DIR_PATH, 'permutations')
    os.makedirs(output_folder, exist_ok=True)

    # For each permutation, combine the images, and then save the result.
    for i, permutation in enumerate(permutations):
        result = combine_images(list(permutation))
        result.save(os.path.join(output_folder, f'{i}.png'))

if __name__ == "__main__":
    # User interface for the script.
    # Loop until valid numeric input is received.
    while True:
        size = input("Enter sample size (0 for full): ")
        if size.isnumeric():
            size = int(size)
            break
        print("Please enter a valid number!")

    if size:
        main(size)
    else:
        main()
