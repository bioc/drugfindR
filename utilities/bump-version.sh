#!/bin/bash
set -euo pipefail

# Define file paths
DESCRIPTION_FILE="DESCRIPTION"
CODEMETA_FILE="codemeta.json"

# Extract the base version (MAJOR.MINOR) from the DESCRIPTION file
BASE_VERSION=$(grep '^Version:' $DESCRIPTION_FILE | awk '{print $2}' | cut -d. -f1,2)

# Get the total number of commits in the Git history (this will be used as the patch number)
PATCH_NUMBER=$(git rev-list --count HEAD)

# Combine the base version with the patch number
NEW_VERSION="$BASE_VERSION.$PATCH_NUMBER"

# Get the current version from the DESCRIPTION file
CURRENT_VERSION=$(grep '^Version:' $DESCRIPTION_FILE | awk '{print $2}' || true)

# Check if the version is already up to date
if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
  echo "Version is already up-to-date: $NEW_VERSION"
  exit 0
fi

echo "Updating version to: $NEW_VERSION"

export SKIP="bump-version,codemeta-json-updated"

# Update the DESCRIPTION file with the new version
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/Version: $CURRENT_VERSION/Version: $NEW_VERSION/" $DESCRIPTION_FILE
else
  sed -i "s/Version: $CURRENT_VERSION/Version: $NEW_VERSION/" $DESCRIPTION_FILE
fi

# Update the codemeta.json file with the new version (assuming the version is under a "version" key)
jq --arg new_version "$NEW_VERSION" '.version = $new_version' "$CODEMETA_FILE" >tmp.$$.json && mv tmp.$$.json "$CODEMETA_FILE"

# Stage the updated files
git add $DESCRIPTION_FILE $CODEMETA_FILE

echo "Version updated to $NEW_VERSION."
