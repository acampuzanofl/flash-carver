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

# Generic function to handle extraction based on regex
generic_handler() {
    local line=$1
    local size_regex=$2
    local filetype=$3

    # Extract the offset from the line
    offset=$(echo "$line" | awk '{print $1}')
    
    # Extract the size using the provided regex
    size=$(echo "$line" | grep -oP "$size_regex")

    if [[ -n "$size" ]]; then
        output_file="$OUTPUT_DIR/${filetype}_${offset}"
        carve_file "$offset" "$size" "$output_file"
    else
        echo "Failed to extract $filetype size from line: $line"
    fi
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
    generic_handler "$line" '(?<=size: )\d+' "cramfs"
}

# Function to handle uImage extraction
handle_uimage() {
    local line=$1
    generic_handler "$line" '(?<=image size: )\d+' "uimage"
}

# Function to handle SquashFS extraction
handle_squashfs() {
    local line=$1
    generic_handler "$line" '(?<!blocksize: )(?<=size: )\d+' "squashfs"
}

# Function to handle Linux ext extraction
handle_linuxext() {
    local line=$1
    generic_handler "$line" '(?<=image size: )\d+(?=,)' "linuxext"
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
