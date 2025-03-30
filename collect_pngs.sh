#!/bin/bash

# Base directory
BASE_DIR=$(pwd)

# Find all files named 'messzeiten.png' and process them
find . -type f -name "*messzeiten.png" | while read -r file; do
    # Get the relative path and replace '/' with '_'
    relative_path=$(dirname "${file#./}")
    sanitized_path=$(echo "$relative_path" | tr '/' '_')
    
    # Construct new filename
    new_filename="messzeiten_${sanitized_path}.png"
    
    # Copy the file to base directory with the new name
    cp "$file" "$BASE_DIR/$new_filename"

    echo "Copied: $file -> $BASE_DIR/$new_filename"
done

echo "All files collected!"