#!/usr/bin/env python3

import os
from PIL import Image

# Set your variables here
image_directory = "/home/david/Documents/Wizard_Army/wizard_army_pinata"  # Change this to your image directory path
IMAGE_WIDTH = 600
IMAGE_HEIGHT = 600

def resize_image(image_path, width, height):
    with Image.open(image_path) as im:
        im_resized = im.resize((width, height))
        im_resized.save(image_path)

def process_directory(directory, width, height):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tiff')):
                image_path = os.path.join(root, file)
                with Image.open(image_path) as im:
                    if im.width != width or im.height != height:
                        resize_image(image_path, width, height)

if __name__ == '__main__':
    process_directory(image_directory, IMAGE_WIDTH, IMAGE_HEIGHT)
