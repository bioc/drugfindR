#!/bin/bash
set -euo pipefail

# Define file paths
DESCRIPTION_FILE="DESCRIPTION"
CODEMETA_FILE="codemeta.json"
VERSION_FILE="VERSION.txt"

# Ensure the version file exists
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Version file not found! Creating one with the current DESCRIPTION version."
  grep '^Version:' $DESCRIPTION_FILE | awk '{print $2}' >"$VERSION_FILE"
fi

# Get the current versions from the files
EXTERNAL_VERSION=$(cat "$VERSION_FILE")
CURRENT_VERSION=$(grep '^Version:' $DESCRIPTION_FILE | awk '{print $2}')

# Function to compare two version numbers (X.Y.Z)
function version_diff() {
  local v1="$1"
  local v2="$2"

  # Split versions into major, minor, and patch
  IFS='.' read -r -a v1_parts <<<"$v1"
  IFS='.' read -r -a v2_parts <<<"$v2"

  # Calculate the patch difference (assuming major and minor are equal)
  local patch_diff=$((v1_parts[2] - v2_parts[2]))
  echo $patch_diff
}

# Compare versions and calculate patch difference
PATCH_DIFF=$(version_diff "$CURRENT_VERSION" "$EXTERNAL_VERSION")

# Ensure that the version bump is at most 1
if [[ "$PATCH_DIFF" -gt 1 ]]; then
  echo "Error: Version in $VERSION_FILE is more than 1 patch ahead of the version in $DESCRIPTION_FILE."
  echo "No version bump will be performed. Please manually synchronize the versions."
  exit 1
fi

# Increment version only if they match or are 1 patch away
if [[ "$EXTERNAL_VERSION" == "$CURRENT_VERSION" || "$PATCH_DIFF" -eq 1 ]]; then
  # Split the version number into major, minor, and patch parts
  IFS='.' read -r -a VERSION_PARTS <<<"$CURRENT_VERSION"
  MAJOR=${VERSION_PARTS[0]}
  MINOR=${VERSION_PARTS[1]}
  PATCH=${VERSION_PARTS[2]}

  # Increment the patch version by 1
  NEW_PATCH=$((PATCH + 1))
  NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"

  # Update the DESCRIPTION file with the new version
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS (BSD sed)
    sed -i '' "s/Version: $CURRENT_VERSION/Version: $NEW_VERSION/" $DESCRIPTION_FILE
  else
    # Linux (GNU sed)
    sed -i "s/Version: $CURRENT_VERSION/Version: $NEW_VERSION/" $DESCRIPTION_FILE
  fi

  # Update the codemeta.json file with the new version (assuming the version is under a "version" key)
  jq --arg new_version "$NEW_VERSION" '.version = $new_version' "$CODEMETA_FILE" >tmp.$$.json && mv tmp.$$.json "$CODEMETA_FILE"

  # Update the external version file with the new version
  echo "$NEW_VERSION" >"$VERSION_FILE"

  # Stage the files
  git add $DESCRIPTION_FILE $CODEMETA_FILE $VERSION_FILE

  # Output the new version
  echo "Bumped version to $NEW_VERSION"
else
  echo "Versions in DESCRIPTION and VERSION.txt do not require a bump."
  exit 0
fi
