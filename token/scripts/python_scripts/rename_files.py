#!/usr/bin/env python3
import os
import shutil
import hashlib


def get_hashed_name(filename):
    """
    Returns the first 16 characters of the SHA-256 hash of the filename.
    """
    return hashlib.sha256(filename.encode()).hexdigest()[:16]


def rename_files_in_directory(directory_path):
    # First, hash the filenames
    for root, _, files in os.walk(directory_path):
        for filename in files:
            file_path = os.path.join(root, filename)
            _, file_extension = os.path.splitext(filename)
            hashed_filename = get_hashed_name(filename) + file_extension
            hashed_file_path = os.path.join(root, hashed_filename)
            os.rename(file_path, hashed_file_path)

    # Then, rename the hashed filenames to numbered filenames
    for root, _, files in os.walk(directory_path):
        files = sorted(files)

        counter = 1
        for filename in files:
            file_path = os.path.join(root, filename)
            if os.path.isfile(file_path):
                forced_ext = '.png'
                new_filename = f"{counter}{forced_ext}"
                new_file_path = os.path.join(root, new_filename)

                # If the new name is the same as the old one, continue to the next file without changing the counter
                if new_file_path == file_path:
                    counter += 1
                    continue

                # Check if the file with the new name already exists.
                while os.path.exists(new_file_path):
                    counter += 1
                    new_filename = f"{counter}{forced_ext}"
                    new_file_path = os.path.join(root, new_filename)

                os.rename(file_path, new_file_path)
                counter += 1

    # Finally, move files from special directories to their parent directories
    for root, dirs, _ in os.walk(directory_path):
        for d in dirs:
            if d.strip().lower() in ["air", "water", "earth", "fire"]:
                subdir_path = os.path.join(root, d)
                for filename in os.listdir(subdir_path):
                    old_path = os.path.join(subdir_path, filename)
                    new_name = d[0].lower() + filename
                    new_path = os.path.join(root, new_name)
                    shutil.move(old_path, new_path)
                os.rmdir(subdir_path)


def main():
    directory_to_search = '/home/david/Documents/Wizard_Army/art_temp'
    rename_files_in_directory(directory_to_search)
    print("Files have been renamed!")


if __name__ == "__main__":
    main()
