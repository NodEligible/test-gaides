#!/bin/bash

# Variables
IMAGE_TAR="glacier-verifier-v0.0.3.tar"
EXTRACT_DIR="glacier-verifier-extract"
MODIFIED_TAR="glacier-verifier-modified.tar"

# Step 1: Clean previous extraction if exists
if [ -d "$EXTRACT_DIR" ]; then
  echo "Cleaning previous extraction..."
  rm -rf "$EXTRACT_DIR"
fi

# Step 2: Extract the image tar
echo "Extracting image tar..."
mkdir "$EXTRACT_DIR"
tar -xf "$IMAGE_TAR" -C "$EXTRACT_DIR"

# Step 3: Ask for private key
read -p "Enter your private key: " PRIVATE_KEY

# Step 4: Inject private key into image (as an example, creating a file with the key)
BLOBS_DIR=$(find "$EXTRACT_DIR" -type d -name blobs)
echo "Adding private key to the image..."
echo "$PRIVATE_KEY" > "$BLOBS_DIR/private_key.txt"

# Step 5: Repack the modified image
echo "Repacking modified image..."
tar -cf "$MODIFIED_TAR" -C "$EXTRACT_DIR" .

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$EXTRACT_DIR"

echo "Modified image saved as $MODIFIED_TAR"
