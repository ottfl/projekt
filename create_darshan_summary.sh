#!/bin/bash

# Base directory
BASE_DIR=$(pwd)

# Find darshan logs and process them to reports
# find . -type f -name "*.darshan" | while read -r file; do
#     log_path=$(dirname "${file#./}")
#     filename=$(basename "$file")
#     cd "$log_path"

#     # Create darshan report
#     python3 -m darshan summary "$filename"

#     # Get wrong jobid from darshan report
#     wrong_jobid=$(echo "$filename" | grep -oP 'id\K\w+')
#     # echo "Wrong jobid: $wrong_jobid"
#     # echo "FileName: $filename"

#     # Get correct jobid from LOG.o
#     correct_jobid=$(grep -oP 'SLURM_JOBID=\K\w+' LOG.o)
#     # echo "Correct jobid: $correct_jobid"

#     find . -type f -name "*report*" -exec sed -i "s/$wrong_jobid/$correct_jobid/g" {} \;
#     cd "$BASE_DIR"
# done

# Rename and copy files to base dir
find . -type f -name "*report.html*" | while read -r file; do
    # Get the relative path and replace '/' with '_'
    relative_path=$(dirname "${file#./}")
    sanitized_path=$(echo "$relative_path" | tr '/' '_')
    
    # Construct new filename
    new_filename="darshan_${sanitized_path}.html"
    
    # Copy the file to base directory with the new name
    cp "$file" "$BASE_DIR/$new_filename"

    echo "Copied: $file -> $BASE_DIR/$new_filename"
done