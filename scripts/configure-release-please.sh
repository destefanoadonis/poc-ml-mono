#!/bin/bash
set -euo pipefail

# This script is expected to run from the repository root.
# It assumes that:
#   - Your packages live in the "packages" directory.
#   - .release-please-manifest.json is in the repository root.

# Define paths (relative to the repository root)
MANIFEST_FILE=".release-please-manifest.json"
PACKAGES_DIR="packages"

# Default versions that won't overwrite .release-please-manifest.json
DEFAULT_VERSIONS=("0.0.0" "0.1.0")

# If the manifest file doesn't exist, create an empty JSON object.
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "{}" > "$MANIFEST_FILE"
fi

# Function: get_version
# Given a package directory, returns just the version number from its pyproject.toml.
# This solution assumes that the version is in the [project] section.
get_version() {
    local pkg_dir="$1"
    local toml_file="$pkg_dir/pyproject.toml"
    
    if [ ! -f "$toml_file" ]; then
        echo ""
        return 1
    fi

    # Search for the [project] section, then within a few lines find the version line.
    #
    # Explanation:
    #   - grep -A 5 '^\[project\]' "$toml_file" finds the [project] section and the next 5 lines.
    #   - The subsequent grep extracts the line containing "version =" (possibly with leading spaces).
    #   - head -n1 ensures we take only the first match.
    #   - sed extracts just the version number inside the quotes.
    local version
    version=$(grep -A 5 '^\[project\]' "$toml_file" \
              | grep -E '^\s*version\s*=' \
              | head -n1 \
              | sed -E 's/^\s*version\s*=\s*"([^"]+)".*$/\1/')
    
    if [ -z "$version" ]; then
        echo "Error: Could not read version from $toml_file" >&2
        return 1
    fi

    echo "$version"
}

# Function: update_manifest
# Given a package name and version string, update the manifest file if the version
# is not one of the default placeholders.
update_manifest() {
    local pkg_name="$1"
    local version="$2"
    if [[ ! " ${DEFAULT_VERSIONS[*]} " =~ " ${version} " ]]; then
        echo "Updating manifest: packages/$pkg_name => $version"
        jq --arg key "packages/$pkg_name" --arg ver "$version" '.[$key] = $ver' "$MANIFEST_FILE" > tmp_manifest.json && mv tmp_manifest.json "$MANIFEST_FILE"
    else
        echo "Version $version for package $pkg_name is a default placeholder; skipping manifest update."
    fi
}

# Main function to process each package
configure_release_please() {
    for pkg in "$PACKAGES_DIR"/*; do
        if [ -d "$pkg" ]; then
            local pkg_name
            pkg_name=$(basename "$pkg")
            echo "Processing package: $pkg_name"
            if [ -f "$pkg/pyproject.toml" ]; then
                local version
                version=$(get_version "$pkg") || {
                    echo "No version found for package $pkg_name; skipping manifest update."
                    continue
                }
                echo "Found version for $pkg_name: $version"
                update_manifest "$pkg_name" "$version"
            else
                echo "No pyproject.toml found in $pkg; skipping version extraction."
            fi
        fi
    done
}

# Run the configuration
configure_release_please
