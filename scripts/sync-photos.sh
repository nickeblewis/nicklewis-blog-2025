#!/bin/bash

# sync-photos.sh - Download photos from iCloud to blog project
# Usage: ./scripts/sync-photos.sh [favorites|album_name]

set -e

# Configuration
APPLE_ID="${APPLE_ID:-}"
PROJECT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
PHOTOS_DIR="$PROJECT_DIR/public/images"
TEMP_DIR="/tmp/icloud-photos-download"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if icloudpd is installed
check_dependencies() {
    if ! command -v icloudpd &> /dev/null; then
        error "icloudpd is not installed. Install it with: pip install icloudpd"
    fi
}

# Get Apple ID if not set
get_apple_id() {
    if [ -z "$APPLE_ID" ]; then
        read -p "Enter your Apple ID: " APPLE_ID
    fi
}

# Create directories
setup_directories() {
    mkdir -p "$TEMP_DIR"
    mkdir -p "$PHOTOS_DIR"
}

# Download photos based on type
download_photos() {
    local download_type="${1:-all}"
    
    log "Starting photo download: $download_type"
    
    case $download_type in
        "favorites")
            log "Downloading favorite photos..."
            icloudpd --username "$APPLE_ID" \
                     --directory "$TEMP_DIR" \
                     --folder-structure none \
                     --set-exif-datetime \
                     --skip-videos \
                     --album "Favorites" \
                     --recent 365
            ;;
        "all")
            log "Downloading all recent photos..."
            icloudpd --username "$APPLE_ID" \
                     --directory "$TEMP_DIR" \
                     --folder-structure none \
                     --set-exif-datetime \
                     --skip-videos \
                     --recent 90
            ;;
        *)
            log "Downloading from album: $download_type"
            icloudpd --username "$APPLE_ID" \
                     --directory "$TEMP_DIR" \
                     --folder-structure none \
                     --set-exif-datetime \
                     --skip-videos \
                     --album "$download_type"
            ;;
    esac
}

# Process and move photos to project
process_photos() {
    log "Processing downloaded photos..."
    
    # Find all downloaded photos
    photos_count=$(find "$TEMP_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" \) | wc -l)
    
    if [ "$photos_count" -eq 0 ]; then
        warn "No photos found to process"
        return
    fi
    
    log "Found $photos_count photos to process"
    
    # Convert HEIC to JPEG if needed and copy to project
    find "$TEMP_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" \) | while read -r photo; do
        filename=$(basename "$photo")
        
        # Convert HEIC to JPEG if necessary
        if [[ "${filename,,}" == *.heic ]]; then
            if command -v magick &> /dev/null; then
                jpeg_name="${filename%.*}.jpg"
                magick "$photo" "$PHOTOS_DIR/$jpeg_name"
                log "Converted and copied: $jpeg_name"
            else
                warn "ImageMagick not found. Skipping HEIC file: $filename"
            fi
        else
            cp "$photo" "$PHOTOS_DIR/"
            log "Copied: $filename"
        fi
    done
}

# Optimize images for web
optimize_images() {
    if command -v magick &> /dev/null; then
        log "Optimizing images for web..."
        find "$PHOTOS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -newer "$TEMP_DIR" | while read -r image; do
            # Resize if too large and optimize
            magick "$image" -resize "1920x1920>" -quality 85 "$image"
            log "Optimized: $(basename "$image")"
        done
    else
        warn "ImageMagick not found. Skipping image optimization."
    fi
}

# Cleanup
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Main function
main() {
    local download_type="${1:-favorites}"
    
    log "Starting iCloud photo sync for blog project"
    
    check_dependencies
    get_apple_id
    setup_directories
    
    download_photos "$download_type"
    process_photos
    optimize_images
    cleanup
    
    log "Photo sync completed! Check $PHOTOS_DIR for your photos."
    log "You may need to run 'pnpm build' to regenerate the site with new images."
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [TYPE]

Download photos from iCloud to your blog project.

OPTIONS:
    -h, --help     Show this help message

TYPE:
    favorites      Download only favorite photos (default)
    all           Download all recent photos (last 90 days)
    "Album Name"  Download from specific album

ENVIRONMENT VARIABLES:
    APPLE_ID      Your Apple ID email (will prompt if not set)

EXAMPLES:
    $0                          # Download favorites
    $0 favorites               # Download favorites
    $0 all                     # Download all recent
    $0 "My Trip Photos"        # Download from specific album

REQUIREMENTS:
    - icloudpd: pip install icloudpd
    - ImageMagick (optional): for HEIC conversion and optimization
EOF
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
