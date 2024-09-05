#!/bin/bash

# Set the binwalk log file and flash file
LOG_FILE="binwalk.log"
FLASH_FILE="flash.bin"

# Output directory for extracted files
OUTPUT_DIR="./extracted_files"
mkdir -p $OUTPUT_DIR

# Map of descriptions to handler functions
declare -A handlers=(
    ["CramFS filesystem"]="handle_cramfs"
    ["uImage header"]="handle_uimage"
)

# Function to handle CramFS extraction
handle_cramfs() {
    local line=$1
    
    # Extract the offset and size from the line
    offset=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | grep -oP '(?<=size: )\d+')

    if [[ -n "$size" ]]; then
        echo "Extracting CramFS at offset $offset with size $size..."
        output_file="$OUTPUT_DIR/cramfs_${offset}.fs"
        dd if="$FLASH_FILE" of="$output_file" bs=1 skip="$offset" count="$size" status=none
    else
        echo "Failed to extract CramFS size from line: $line"
    fi
}

# Function to handle uImage extraction
handle_uimage() {
    local line=$1

    # Extract the offset and size from the line
    offset=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | grep -oP '(?<=image size: )\d+')

    if [[ -n "$size" ]]; then
        echo "Extracting uImage at offset $offset with size $size..."
        output_file="$OUTPUT_DIR/uimage_${offset}.img"
        dd if="$FLASH_FILE" of="$output_file" bs=1 skip="$offset" count="$size" status=none
    else
        echo "Failed to extract uImage size from line: $line"
    fi
}

# Read through the binwalk log and process each line
while IFS= read -r line; do
    # Check each description in the map
    for description in "${!handlers[@]}"; do
        if [[ "$line" == *"$description"* ]]; then
            # Call the corresponding handler with the full line
            ${handlers[$description]} "$line"
            break
        fi
    done
done < "$LOG_FILE"

echo "Extraction complete."
