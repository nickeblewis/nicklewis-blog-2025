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

# Sanitize album name for filesystem use
sanitize_album_name() {
    local album_name="$1"
    # Remove/replace problematic characters and convert to lowercase
    echo "$album_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Process and move photos to project
process_photos() {
    local download_type="${1:-all}"
    local target_dir="$PHOTOS_DIR"
    
    # Create album subfolder if album name is provided
    if [[ "$download_type" != "all" && "$download_type" != "favorites" ]]; then
        local sanitized_album=$(sanitize_album_name "$download_type")
        target_dir="$PHOTOS_DIR/$sanitized_album"
        mkdir -p "$target_dir"
        log "Created album folder: $target_dir"
    fi
    
    log "Processing downloaded photos..."
    
    # Find all downloaded photos
    photos_count=$(find "$TEMP_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.arw" -o -iname "*.dng" -o -iname "*.nef" \) | wc -l)
    
    if [ "$photos_count" -eq 0 ]; then
        warn "No photos found to process"
        return
    fi
    
    log "Found $photos_count photos to process"
    
    # Convert RAW/HEIC to JPEG if needed and copy to project
    find "$TEMP_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.arw" -o -iname "*.dng" -o -iname "*.nef" \) | while read -r photo; do
        filename=$(basename "$photo")
        
        # Convert RAW/HEIC to JPEG if necessary
        lowercase_filename=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$lowercase_filename" == *.heic ]]; then
            if command -v magick >&/dev/null; then
                jpeg_name="${filename%.*}.jpg"
                magick "$photo" "$target_dir/$jpeg_name"
                log "Converted HEIC and copied: $jpeg_name"
            else
                warn "ImageMagick not found. Skipping HEIC file: $filename"
            fi
        elif [[ "$lowercase_filename" == *.arw ]]; then
            if command -v magick >&/dev/null; then
                jpeg_name="${filename%.*}.jpg"
                log "Converting Sony RAW (.arw) to JPEG: $filename"
                # Sony RAW conversion with enhanced settings for better quality
                magick "$photo" -auto-orient -colorspace sRGB -quality 95 "$target_dir/$jpeg_name"
                log "Converted Sony RAW and copied: $jpeg_name"
            else
                warn "ImageMagick not found. Skipping Sony RAW file: $filename"
            fi
        elif [[ "$lowercase_filename" == *.dng ]]; then
            if command -v magick >&/dev/null; then
                jpeg_name="${filename%.*}.jpg"
                log "Converting Adobe DNG to JPEG: $filename"
                # Adobe DNG conversion with enhanced settings for better quality
                magick "$photo" -auto-orient -colorspace sRGB -quality 95 "$target_dir/$jpeg_name"
                log "Converted Adobe DNG and copied: $jpeg_name"
            else
                warn "ImageMagick not found. Skipping Adobe DNG file: $filename"
            fi
        elif [[ "$lowercase_filename" == *.nef ]]; then
            if command -v magick >&/dev/null; then
                jpeg_name="${filename%.*}.jpg"
                log "Converting Nikon NEF to JPEG: $filename"
                # Nikon NEF conversion with enhanced settings for better quality
                magick "$photo" -auto-orient -colorspace sRGB -quality 95 "$target_dir/$jpeg_name"
                log "Converted Nikon NEF and copied: $jpeg_name"
            else
                warn "ImageMagick not found. Skipping Nikon NEF file: $filename"
            fi
        else
            cp "$photo" "$target_dir/"
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

# Generate a blog post draft with imported photos
generate_blog_post() {
    local download_type="${1:-all}"
    local target_dir="$PHOTOS_DIR"
    local blog_dir="$PROJECT_DIR/src/content/blog"
    
    # Determine the target directory for photos
    if [[ "$download_type" != "all" && "$download_type" != "favorites" ]]; then
        local sanitized_album=$(sanitize_album_name "$download_type")
        target_dir="$PHOTOS_DIR/$sanitized_album"
    fi
    
    # Find photos that were just added (newer than temp dir)
    local new_photos=()
    while IFS= read -r -d '' photo; do
        new_photos+=("$photo")
    done < <(find "$target_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -newer "$TEMP_DIR" -print0 2>/dev/null)
    
    if [ ${#new_photos[@]} -eq 0 ]; then
        log "No new photos found, skipping blog post generation"
        return
    fi
    
    # Generate timestamp-based filename
    local timestamp=$(date +'%Y-%m-%d-%H-%M-%S')
    local random_suffix=$(openssl rand -hex 3 2>/dev/null || echo "$(date +%s | tail -c 6)")
    local blog_filename="$timestamp-$random_suffix.md"
    local blog_file="$blog_dir/$blog_filename"
    
    # Determine title and category
    local title
    local category="Photography"
    if [[ "$download_type" != "all" && "$download_type" != "favorites" ]]; then
        title="$download_type"
    else
        title="Photo Collection - $(date +'%B %d, %Y')"
    fi
    
    # Generate hero image (first photo) with correct path
    local hero_image=""
    if [ ${#new_photos[@]} -gt 0 ]; then
        local first_photo="${new_photos[0]}"
        local relative_path="${first_photo#$PROJECT_DIR/public/}"
        hero_image="/$relative_path"
    fi
    
    # Create the blog post
    cat > "$blog_file" << EOF
---
heroImage: $hero_image
category: $category
description: Generated from iCloud photo sync - edit this description
pubDate: $(date -u +'%Y-%m-%dT%H:%M:%S.000Z')
tags:
  - photos
  - imported
title: $title
draft: true
---

<!-- Edit this content and remove the draft flag when ready to publish -->

EOF
    
    # Add all photos as markdown images
    for photo in "${new_photos[@]}"; do
        local relative_path="${photo#$PROJECT_DIR/public/}"
        local photo_path="/images/$relative_path"
        echo "![](${photo_path})" >> "$blog_file"
        echo "" >> "$blog_file"
    done
    
    # Add some placeholder content
    cat >> "$blog_file" << EOF

<!-- Add your content here -->

This post contains ${#new_photos[@]} photos imported from iCloud.

<!-- Remember to:
- Edit the title and description
- Add meaningful content
- Update tags as needed
- Remove the draft flag when ready
- Consider adding alt text to images
-->
EOF
    
    log "Generated blog post: $blog_file"
    log "Photos included: ${#new_photos[@]}"
    log "Remember to edit the post content and remove 'draft: true' when ready to publish!"
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
    process_photos "$download_type"
    optimize_images
    
    # Ask user if they want to generate a blog post
    echo
    read -p "Would you like to generate a blog post draft with the imported photos? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        generate_blog_post "$download_type"
    fi
    
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
    favorites      Download only favorite photos (default) - saves to public/images/
    all           Download all recent photos (last 90 days) - saves to public/images/
    "Album Name"  Download from specific album - creates subfolder public/images/album-name/

FEATURES:
    - Creates album-specific subfolders when downloading from named albums
    - Album names are sanitized for filesystem compatibility (lowercase, special chars become hyphens)
    - HEIC files are automatically converted to JPEG format
    - RAW files are automatically converted to JPEG format with high quality settings:
      • Sony Alpha RAW (.arw)
      • Adobe Digital Negative (.dng)
      • Nikon Electronic Format (.nef)
    - Images are optimized for web (resized to max 1920px, 85% quality)
    - Optional blog post generation with imported photos as markdown images
    - Generated posts include proper frontmatter and are marked as drafts

ENVIRONMENT VARIABLES:
    APPLE_ID      Your Apple ID email (will prompt if not set)

EXAMPLES:
    $0                          # Download favorites to public/images/
    $0 favorites               # Download favorites to public/images/
    $0 all                     # Download all recent to public/images/
    $0 "My Trip Photos"        # Download to public/images/my-trip-photos/
    $0 "Family Events 2024"    # Download to public/images/family-events-2024/

REQUIREMENTS:
    - icloudpd: pip install icloudpd
    - ImageMagick (required): for HEIC/RAW conversion and optimization
      Install with: brew install imagemagick
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
