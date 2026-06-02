#!/bin/bash

REPO_ROOT="/var/www/html/local-repo/ubuntu"
POOL_DIR="$REPO_ROOT/pool/main"
OUTPUT_DIR="$REPO_ROOT/dists/focal/main/binary-amd64"
TEMP_PACKAGES="$OUTPUT_DIR/Packages"

> "$TEMP_PACKAGES"

echo "Memulai indexing repository..."

find "$POOL_DIR" -type f -name "*.deb" | while read -r FULL_PATH; do

	deb=$(basename "$FULL_PATH")
	echo "Processing $deb..." >&2

	RELATIVE_PATH=${FULL_PATH#$REPO_ROOT/}
	CONTROL_FILE=$(ar t "$FULL_PATH" | grep control)
	ar x "$FULL_PATH" "$CONTROL_FILE"

	if [[ "$CONTROL_FILE" == *.zst ]]; then
		zstdcat "$CONTROL_FILE" | tar -xOf - ./control >> "$TEMP_PACKAGES"
	else
		tar -xOf "$CONTROL_FILE" ./control >> "$TEMP_PACKAGES"
	fi

	echo "Filename: $RELATIVE_PATH" >> "$TEMP_PACKAGES"
	echo "Size: $(stat -c%s "$FULL_PATH")" >> "$TEMP_PACKAGES"
	echo "MD5sum: $(md5sum "$FULL_PATH" | cut -d' ' -f1)" >> "$TEMP_PACKAGES"
	echo "SHA1: $(sha1sum "$FULL_PATH" | cut -d' ' -f1)" >> "$TEMP_PACKAGES"
	echo "SHA256: $(sha256sum "$FULL_PATH" | cut -d' ' -f1)" >> "$TEMP_PACKAGES"
	echo "" >> "$TEMP_PACKAGES"
	rm -f "$CONTROL_FILE"

done

gzip -9c "$TEMP_PACKAGES" > "${TEMP_PACKAGES}.gz"

echo "-------------------------------------------------------"
echo "Done! Index dibuat di: $OUTPUT_DIR"
