#!/bin/bash

# Set the binwalk log file and flash file
LOG_FILE="binwalk.log"
FLASH_FILE="flash.bin"

# Output directory for extracted files
OUTPUT_DIR="./extracted_files"
mkdir -p $OUTPUT_DIR

# Function to carve out a file using tail and head
carve_file() {
    local offset=$1
    local size=$2
    local output_file=$3

    echo "Carving file at offset $offset with size $size into $output_file"
    tail -c +$((offset + 1)) "$FLASH_FILE" | head -c $size > "$output_file"
}

# Map of descriptions to handler functions
declare -A handlers=(
    ["CramFS filesystem"]="handle_cramfs"
    ["uImage header"]="handle_uimage"
    ["Squashfs filesystem"]="handle_squashfs"
    ["Linux EXT filesystem"]="handle_linuxext"
)

# Function to handle CramFS extraction
handle_cramfs() {
    local line=$1

    # Extract the offset and size from the line
    offset=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | grep -oP '(?<=size: )\d+')

    if [[ -n "$size" ]]; then
        output_file="$OUTPUT_DIR/cramfs_${offset}.fs"
        carve_file "$offset" "$size" "$output_file"
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
        output_file="$OUTPUT_DIR/uimage_${offset}.img"
        carve_file "$offset" "$size" "$output_file"
    else
        echo "Failed to extract uImage size from line: $line"
    fi
}

# Function to handle squashfs extraction
handle_squashfs() {
    local line=$1
    offset=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | grep -oP '(?<!blocksize: )(?<=size: )\d+')

    if [[ -n "$size" ]]; then
        output_file="$OUTPUT_DIR/squashfs_${offset}.fs"
        carve_file "$offset" "$size" "$output_file"
    else
        echo "Failed to extract SquashFS size from line: $line"
    fi
}

# Function to handle linux ext filesystem extraction
handle_linuxext() {
    local line=$1
    offset=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | grep -oP '(?<=image size: )\d+(?=,)')

    if [[ -n "$size" ]]; then
        output_file="$OUTPUT_DIR/linuxext_${offset}.ext"
        carve_file "$offset" "$size" "$output_file"
    else
        echo "Failed to extract linux ext size from line: $line"
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
