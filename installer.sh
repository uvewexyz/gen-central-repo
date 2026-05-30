#!/bin/bash

# Path variables
REPO_ROOT="/var/www/html/local-repo/ubuntu"
TEMP_DIR="/tmp/ubuntu-index"
mkdir -p "$TEMP_DIR"

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Define Ubuntu 20.04 (focal) index variable
SUITES=("focal" "focal-updates" "focal-security" "focal-backports")
COMPONENTS=("main" "universe" "multiverse" "restricted")

echo -e "=============================================="
echo -e "   ALL-FOCAL PACKAGE DOWNLOADER FOR RHEL 8"
echo -e "=============================================="
read -p "Input the name package to download (example: nginx mysql): " -a PACKAGES

if [ ${#PACKAGES[@]} -eq 0 ]; then
	echo -e "${RED}[FAILED !]${NC}: Empty input, bye!"
	exit 1
fi

# 2. Download package index
echo -e "--> ${YELLOW}[CHANGED !]${NC}: Extracting all Focal manifests..."
for suite in "${SUITES[@]}"; do
	for comp in "${COMPONENTS[@]}"; do
		INDEX_PATH="$TEMP_DIR/${suite}_${comp}"
		wget -q "https://archive.ubuntu.com/ubuntu/dists/${suite}/${comp}/binary-amd64/Packages.gz" -O "${INDEX_PATH}.gz"
		
		if [ -f "${INDEX_PATH}.gz" ]; then
			gunzip -f "${INDEX_PATH}.gz" 2>/dev/null
		fi
	done
done

# 3. Start to search package
for pkg in "${PACKAGES[@]}"; do
	echo -e "=============================================="
	echo -e "Searching for package: $pkg"
	
	for suite in "${SUITES[@]}"; do
		for comp in "${COMPONENTS[@]}"; do
			INDEX_PATH="$TEMP_DIR/${suite}_${comp}"
			
			# Ignoring failed download packages
			[ ! -f "$INDEX_PATH" ] && continue

			# Filtering and searching for matching packages
			FILENAMES=$(grep -A 20 "Package: $pkg" "$INDEX_PATH" | grep "Filename:" | awk '{print $2}')
			if [ -n "$FILENAMES" ]; then
				echo -e "--> ${GREEN}[COMPLETED !]${NC}: Package ready in index $suite - $comp "
				TARGET_DIR="$REPO_ROOT/pool/main/$pkg"
				
				# Create directory for package if not found
				if [ ! -d "$TARGET_DIR" ]; then
					echo -e "    ${YELLOW}[CHANGED !]${NC}: Creating directory: $TARGET_DIR"
					mkdir -p "$TARGET_DIR"
				fi
				
				# Download package process
				for pkg_install in $FILENAMES; do
					DOWNLOAD_URL="https://archive.ubuntu.com/ubuntu/$pkg_install"
					FILE_NAME=$(basename "$pkg_install")
					
					# Pengecekan file: Skip jika sudah pernah didownload
					if [ -f "$TARGET_DIR/$FILE_NAME" ]; then
						echo -e "    ${GREEN}[COMPLETED !]${NC}: Package $FILE_NAME exists!"
					else
						echo -e "    ${YELLOW}[CHANGED !]${NC}: Download $FILE_NAME"
						wget -q --show-progress -P "$TARGET_DIR" "$DOWNLOAD_URL"
					fi
				done
			fi
		done
	done
done

# 4. Clear indeks file
rm -rf "$TEMP_DIR"
echo -e "=============================================="
echo -e "${GREEN}[COMPLETED !]${NC}: Completed!"
