#!/bin/bash

REPO_ROOT="/var/www/html/local-repo/ubuntu"
POOL_DIR="$REPO_ROOT/pool/main"
OUTPUT_DIR="$REPO_ROOT/dists/focal/main/binary-amd64"
TEMP_PACKAGES="$OUTPUT_DIR/Packages"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

> "$TEMP_PACKAGES"

echo -e "${YELLOW}[CHANGED !]${NC}: Create index file!"

find "$POOL_DIR" -type f -name "*.deb" | while read -r FULL_PATH; do

	deb=$(basename "$FULL_PATH")
	echo -e "Processing $deb..." >&2

	RELATIVE_PATH=${FULL_PATH#$REPO_ROOT/}
	CONTROL_FILE=$(ar t "$FULL_PATH" | grep control)
	ar x "$FULL_PATH" "$CONTROL_FILE"

	if [[ "$CONTROL_FILE" == *.zst ]]; then
		zstdcat "$CONTROL_FILE" | tar -xOf - ./control >> "$TEMP_PACKAGES"
	else
		tar -xOf "$CONTROL_FILE" ./control >> "$TEMP_PACKAGES"
	fi

	echo -e "Filename: $RELATIVE_PATH" >> "$TEMP_PACKAGES"
	echo -e "Size: $(stat -c%s "$FULL_PATH")" >> "$TEMP_PACKAGES"
	echo -e "MD5sum: $(md5sum "$FULL_PATH" | cut -d' ' -f1)" >> "$TEMP_PACKAGES"
	echo -e "SHA1: $(sha1sum "$FULL_PATH" | cut -d' ' -f1)" >> "$TEMP_PACKAGES"
	echo -e "SHA256: $(sha256sum "$FULL_PATH" | cut -d' ' -f1)" >> "$TEMP_PACKAGES"
	echo -e "" >> "$TEMP_PACKAGES"
	rm -f "$CONTROL_FILE"

done

gzip -9c "$TEMP_PACKAGES" > "${TEMP_PACKAGES}.gz"

echo -e "-------------------------------------------------------"
echo -e "${GREEN}[COMPLETED !]${NC}: Done! Index created in $OUTPUT_DIR"
