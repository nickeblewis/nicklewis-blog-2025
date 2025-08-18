#!/bin/bash

# Import script for converting Logseq pages to blog posts
# Usage: ./scripts/import-from-logseq.sh [logseq_export_path] [options]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BLOG_CONTENT_DIR="$PROJECT_ROOT/src/content/blog"
BLOG_ASSETS_DIR="$PROJECT_ROOT/public/images"
CONFIG_FILE="$SCRIPT_DIR/logseq-import.config"

# Default values
DEFAULT_CATEGORY="Journal"
DEFAULT_DRAFT=false
DEFAULT_HERO_IMAGE="/images/default-hero.jpg"
DRY_RUN=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
    fi
}

# Help function
show_help() {
    cat << EOF
Import script for converting Logseq pages to blog posts

Usage: $0 [LOGSEQ_PATH] [OPTIONS]

Arguments:
    LOGSEQ_PATH         Path to Logseq export directory or specific .md file

Options:
    -c, --category      Default category for imported posts (default: Journal)
    -d, --draft         Import as draft posts (default: false)
    -h, --hero-image    Default hero image path (default: /images/default-hero.jpg)
    -t, --tags          Comma-separated default tags to add to all posts
    -f, --filter        Only import files matching this pattern (regex)
    -e, --exclude       Exclude files matching this pattern (regex)
    --dry-run           Show what would be imported without actually doing it
    --verbose           Enable verbose output
    --help              Show this help message

Examples:
    # Import all pages from Logseq export
    $0 /path/to/logseq/export

    # Import as coding posts with specific tags
    $0 /path/to/logseq/export -c Coding -t "programming,tutorial"

    # Import specific file as draft
    $0 /path/to/page.md --draft --verbose

    # Dry run to see what would be imported
    $0 /path/to/logseq/export --dry-run

Configuration:
    You can create a config file at scripts/logseq-import.config with:
    DEFAULT_CATEGORY="Your Category"
    CATEGORY_MAPPING="logseq-tag:blog-category,another-tag:another-category"
    TAG_MAPPING="old-tag:new-tag,another:mapped"

Available categories: Journal, Coding, Music, Photography, Crypto, History
EOF
}

# Load configuration file if it exists
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_verbose "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# Parse command line arguments
parse_args() {
    LOGSEQ_PATH=""
    IMPORT_CATEGORY="$DEFAULT_CATEGORY"
    IMPORT_DRAFT="$DEFAULT_DRAFT"
    IMPORT_HERO_IMAGE="$DEFAULT_HERO_IMAGE"
    IMPORT_TAGS=""
    FILE_FILTER=""
    FILE_EXCLUDE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--category)
                IMPORT_CATEGORY="$2"
                shift 2
                ;;
            -d|--draft)
                IMPORT_DRAFT=true
                shift
                ;;
            -h|--hero-image)
                IMPORT_HERO_IMAGE="$2"
                shift 2
                ;;
            -t|--tags)
                IMPORT_TAGS="$2"
                shift 2
                ;;
            -f|--filter)
                FILE_FILTER="$2"
                shift 2
                ;;
            -e|--exclude)
                FILE_EXCLUDE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$LOGSEQ_PATH" ]]; then
                    LOGSEQ_PATH="$1"
                else
                    log_error "Multiple arguments interpreted as paths. If your path contains spaces, please enclose it in quotes (e.g., \"/path/with spaces\"). Please specify only one path."
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$LOGSEQ_PATH" ]]; then
        log_error "Please provide the path to Logseq export directory or file"
        show_help
        exit 1
    fi
}

# Validate category
validate_category() {
    local category="$1"
    local valid_categories=("Journal" "Coding" "Music" "Photography" "Crypto" "History")
    
    for valid in "${valid_categories[@]}"; do
        if [[ "$category" == "$valid" ]]; then
            echo "$category"
            return 0
        fi
    done
    
    log_warning "Invalid category '$category'. Using 'Journal' instead."
    log_info "Valid categories: ${valid_categories[*]}"
    echo "Journal"
}

# Extract title from content
extract_title() {
    local file="$1"
    local title=""
    
    # Try to find title from various sources
    # 1. Look for # Title at the beginning
    title=$(grep -m1 "^# " "$file" 2>/dev/null | sed 's/^# *//' | head -c 80 || true)
    
    # 2. If no title found, use filename without extension
    if [[ -z "$title" ]]; then
        title=$(basename "$file" .md)
        title=${title//-/ }  # Replace hyphens with spaces
        title=${title//_/ }  # Replace underscores with spaces
    fi
    
    echo "$title"
}

# Extract description from content
extract_description() {
    local file="$1"
    local description=""
    
    # Look for the first paragraph after title
    description=$(awk '
        /^# / { in_content=1; next }
        in_content && /^[[:space:]]*$/ { next }
        in_content && /^[^#]/ && /./ { 
            gsub(/^[[:space:]]*/, "")
            print $0
            exit 
        }
    ' "$file" 2>/dev/null | head -c 200 || true)
    
    # If no description found, use a generic one
    if [[ -z "$description" ]]; then
        description="Imported from Logseq"
    fi
    
    echo "$description"
}

# Extract tags from content
extract_tags() {
    local file="$1"
    local tags=()
    
    # Look for Logseq-style tags (#tag)
    while IFS= read -r tag; do
        if [[ -n "$tag" ]]; then
            tag=$(echo "$tag" | sed 's/^#//' | tr '[:upper:]' '[:lower:]')
            tags+=("$tag")
        fi
    done < <(grep -oh "#[[:alnum:]_-]\+" "$file" 2>/dev/null | sort -u | head -10 || true)
    
    # Add default tags if specified
    if [[ -n "$IMPORT_TAGS" ]]; then
        IFS=',' read -ra default_tags <<< "$IMPORT_TAGS"
        for tag in "${default_tags[@]}"; do
            tag=$(echo "$tag" | xargs)  # Trim whitespace
            if [[ -n "$tag" ]]; then
                tags+=("$tag")
            fi
        done
    fi
    
    # Return unique tags as YAML array
    if [[ ${#tags[@]} -gt 0 ]]; then
        printf '%s\n' "${tags[@]}" | sort -u | sed 's/^/  - /'
    else
        echo "  - imported"
    fi
}

# Generate slug from title
generate_slug() {
    local title="$1"
    echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g'
}

# Select hero image from content or pick random fallback
select_hero_image() {
    local file="$1"
    local content="$2"
    local source_dir="$(dirname "$file")"
    local hero_image="$IMPORT_HERO_IMAGE"
    
    # First, try to find images in the content
    local first_image=""
    
    # Look for standard markdown images ![alt](path)
    first_image=$(echo "$content" | grep -o '!\[.*\]([^)]*)' | head -1 | sed 's/.*](\([^)]*\)).*/\1/' || true)
    
    # If no standard images, look for Logseq-style images [[image.ext]]
    if [[ -z "$first_image" ]]; then
        first_image=$(echo "$content" | grep -o '!*\[\[.*\]\]' | head -1 | sed 's/.*\[\[\([^]]*\)\]\].*/\1/' | grep -E '\.(jpg|jpeg|png|gif|webp|svg)$' || true)
    fi
    
    # If we found an image in content, use it as hero image
    if [[ -n "$first_image" ]]; then
        local full_image_path="$source_dir/$first_image"
        if [[ -f "$full_image_path" ]]; then
            local image_ext="${first_image##*.}"
            local base_name=$(basename "$first_image" ".${image_ext}")
            local new_image_name="${base_name}.${image_ext}"
            local new_image_path="$BLOG_ASSETS_DIR/$new_image_name"
            
            if [[ "$DRY_RUN" == false ]]; then
                cp "$full_image_path" "$new_image_path"
                log_verbose "Copied hero image: $new_image_name"
            fi
            
            hero_image="/images/${new_image_name}"
            log_verbose "Using content image as hero: $hero_image"
        fi
    else
        # No images in content, pick a random existing image
        local random_image=$(find "$BLOG_ASSETS_DIR" -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" | shuf -n 1 2>/dev/null | head -1 || true)
        
        if [[ -n "$random_image" && -f "$random_image" ]]; then
            local relative_path="/images/$(basename "$random_image")"
            hero_image="$relative_path"
            log_verbose "Using random fallback hero image: $hero_image"
        else
            log_verbose "No images found for hero image, using default"
        fi
    fi
    
    echo "$hero_image"
}

# Process images in content
process_images() {
    local content="$1"
    local source_dir="$2"
    local processed_content="$content"
    local image_counter=1
    
    log_verbose "Processing images in content from source dir: $source_dir"
    
    # Process standard markdown images ![alt](path)
    while IFS= read -r image_ref; do
        if [[ -n "$image_ref" ]]; then
            log_verbose "Processing image reference: $image_ref"
            
            # Extract image path from ![alt](path)
            local image_path=$(echo "$image_ref" | sed 's/.*](\([^)]*\)).*/\1/')
            local alt_text=$(echo "$image_ref" | sed 's/!\[\([^]]*\)].*/\1/')
            
            log_verbose "Extracted image path: '$image_path', alt text: '$alt_text'"
            
            # Handle multiple possible paths for Logseq images
            local full_image_path=""
            local found_image=false
            
            # Try different possible locations
            local possible_paths=(
                "$source_dir/$image_path"
                "$source_dir/assets/$image_path"
                "$(dirname "$source_dir")/assets/$image_path"
                "$source_dir/../assets/$image_path"
            )
            
            for path in "${possible_paths[@]}"; do
                if [[ -f "$path" ]]; then
                    full_image_path="$path"
                    found_image=true
                    log_verbose "Found image at: $path"
                    break
                fi
            done
            
            if [[ "$found_image" == true ]]; then
                local image_ext="${image_path##*.}"
                local base_name=$(basename "$image_path" ".${image_ext}")
                local new_image_name="${base_name}.${image_ext}"
                local new_image_path="$BLOG_ASSETS_DIR/$new_image_name"
                
                # Ensure unique filename if it already exists
                if [[ -f "$new_image_path" ]]; then
                    new_image_name="${base_name}-${image_counter}.${image_ext}"
                    new_image_path="$BLOG_ASSETS_DIR/$new_image_name"
                fi
                
                if [[ "$DRY_RUN" == false ]]; then
                    cp "$full_image_path" "$new_image_path"
                    log_verbose "Copied image: $full_image_path -> $new_image_name"
                fi
                
                # Update content with new image reference
                local new_image_ref="![${alt_text}](/images/${new_image_name})"
                processed_content=${processed_content//$image_ref/$new_image_ref}
                
                ((image_counter++))
            else
                log_warning "Image not found in any of these locations:"
                for path in "${possible_paths[@]}"; do
                    log_warning "  - $path"
                done
                log_warning "Original reference will be preserved: $image_ref"
            fi
        fi
    done < <(echo "$content" | grep -o '!\[.*\]([^)]*)' || true)
    
    # Process Logseq-style image embeds [[image.jpg]] and ![[]]
    while IFS= read -r logseq_ref; do
        if [[ -n "$logseq_ref" ]]; then
            log_verbose "Processing Logseq image reference: $logseq_ref"
            
            # Extract path from [[path]] or ![[path]]
            local image_path=$(echo "$logseq_ref" | sed 's/.*\[\[\([^]]*\)\]\].*/\1/')
            
            # Skip if it's not an image file
            if [[ ! "$image_path" =~ \.(jpg|jpeg|png|gif|webp|svg)$ ]]; then
                continue
            fi
            
            local full_image_path="$source_dir/$image_path"
            if [[ -f "$full_image_path" ]]; then
                local image_ext="${image_path##*.}"
                local base_name=$(basename "$image_path" ".${image_ext}")
                local new_image_name="${base_name}-imported.${image_ext}"
                local new_image_path="$BLOG_ASSETS_DIR/$new_image_name"
                
                if [[ "$DRY_RUN" == false ]]; then
                    cp "$full_image_path" "$new_image_path"
                    log_verbose "Copied Logseq image: $new_image_name"
                fi
                
                # Convert to standard markdown format
                local alt_text=$(basename "$image_path" ".${image_ext}")
                local new_image_ref="![${alt_text}](/images/${new_image_name})"
                processed_content=${processed_content//$logseq_ref/$new_image_ref}
                
                ((image_counter++))
            else
                log_warning "Logseq image not found: $full_image_path"
            fi
        fi
    done < <(echo "$content" | grep -o '!*\[\[.*\]\]' || true)
    
    echo "$processed_content"
}

# Convert Logseq content to blog format
convert_content() {
    local file="$1"
    local content=""
    
    # Read the entire file
    content=$(cat "$file")
    
    # Remove the title if it's the first line (we'll put it in frontmatter)
    content=$(echo "$content" | sed '1{/^# /d;}')
    
    # Strip leading dashes from Logseq bullet points
    # Convert "- Some text" to "Some text", "  - Nested" to "  Nested", etc.
    content=$(echo "$content" | sed 's/^\([[:space:]]*\)- /\1/g')
    
    # Process Logseq-specific syntax
    # Convert block references, embeds, etc.
    content=$(echo "$content" | sed 's/{{[^}]*}}/<!-- Block reference removed -->/g')
    
    # Process images
    content=$(process_images "$content" "$(dirname "$file")")
    
    # Fix any remaining relative image paths that weren't caught by process_images
    # Convert ./public/images/ to /images/
    content=$(echo "$content" | sed 's|\./public/images/|/images/|g')
    # Convert ./assets/image.jpg to /images/image.jpg
    content=$(echo "$content" | sed 's|\./assets/|/images/|g')
    content=$(echo "$content" | sed 's|\.\./assets/|/images/|g')
    
    echo "$content"
}

# Create blog post file
create_blog_post() {
    local source_file="$1"
    local title="$2"
    local description="$3"
    local category="$4"
    local tags="$5"
    local hero_image="$6"
    local draft="$7"
    local slug="$8"
    
    local output_file="$BLOG_CONTENT_DIR/${slug}.mdx"
    local pub_date=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    
    # Create frontmatter
    local frontmatter="---
heroImage: $hero_image
category: $category
description: $description
pubDate: $pub_date
tags:
$tags
title: $title"

    if [[ "$draft" == true ]]; then
        frontmatter+=("
draft: true")
    fi
    
    frontmatter+=("
---")
    
    # Get converted content
    local content=$(convert_content "$source_file")
    
    # Combine frontmatter and content
    local full_content="$frontmatter

$content"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would create: $output_file"
        log_verbose "Content preview:"
        echo "---"
        echo "$frontmatter" | head -20
        echo "---"
        echo "$content" | head -10
        echo "..."
    else
        echo "$full_content" > "$output_file"
        log_success "Created blog post: $output_file"
    fi
    
    return 0
}

# Process single file
process_file() {
    local file="$1"
    
    log_info "Processing file: $(basename "$file")"
    
    # Validate file exists and is readable
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "File not readable: $file"
        return 1
    fi
    
    # Extract metadata
    local title=$(extract_title "$file")
    local description=$(extract_description "$file")
    local category=$(validate_category "$IMPORT_CATEGORY")
    local tags=$(extract_tags "$file")
    local slug=$(generate_slug "$title")
    
    log_verbose "Title: $title"
    log_verbose "Description: $description"
    log_verbose "Category: $category"
    log_verbose "Slug: $slug"
    
    # Check if output file already exists
    local output_file="$BLOG_CONTENT_DIR/${slug}.mdx"
    if [[ -f "$output_file" ]] && [[ "$DRY_RUN" == false ]]; then
        log_warning "Blog post already exists: $output_file"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping $file"
            return 0
        fi
    fi
    
    # Get file content for hero image selection
    local file_content=$(cat "$file")
    
    # Select hero image
    local hero_image=$(select_hero_image "$file" "$file_content")
    
    # Create the blog post
    create_blog_post "$file" "$title" "$description" "$category" "$tags" "$hero_image" "$IMPORT_DRAFT" "$slug"
}

# Process directory
process_directory() {
    local dir="$1"
    local file_count=0
    local processed_count=0
    
    log_info "Scanning directory: $dir"
    
    # Find all markdown files
    while IFS= read -r -d '' file; do
        ((file_count++))
        
        # Apply filters if specified
        if [[ -n "$FILE_FILTER" ]] && [[ ! $(basename "$file") =~ $FILE_FILTER ]]; then
            log_verbose "Skipping file (filter): $(basename "$file")"
            continue
        fi
        
        if [[ -n "$FILE_EXCLUDE" ]] && [[ $(basename "$file") =~ $FILE_EXCLUDE ]]; then
            log_verbose "Skipping file (exclude): $(basename "$file")"
            continue
        fi
        
        if process_file "$file"; then
            ((processed_count++))
        fi
    done < <(find "$dir" -name "*.md" -type f -print0)
    
    log_success "Processed $processed_count out of $file_count markdown files"
}

# Main function
main() {
    log_info "Starting Logseq to blog import process"
    
    # Load configuration
    load_config
    
    # Parse arguments
    parse_args "$@"
    
    # Validate paths
    if [[ ! -e "$LOGSEQ_PATH" ]]; then
        log_error "Path does not exist: $LOGSEQ_PATH"
        exit 1
    fi
    
    if [[ ! -d "$BLOG_CONTENT_DIR" ]]; then
        log_error "Blog content directory not found: $BLOG_CONTENT_DIR"
        log_info "Are you running this from the project root?"
        exit 1
    fi
    
    # Create assets directory if it doesn't exist
    if [[ ! -d "$BLOG_ASSETS_DIR" ]] && [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$BLOG_ASSETS_DIR"
        log_info "Created assets directory: $BLOG_ASSETS_DIR"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN MODE - No files will be created or modified"
    fi
    
    # Process files or directory
    if [[ -f "$LOGSEQ_PATH" ]]; then
        # Single file
        process_file "$LOGSEQ_PATH"
    elif [[ -d "$LOGSEQ_PATH" ]]; then
        # Directory
        process_directory "$LOGSEQ_PATH"
    else
        log_error "Invalid path: $LOGSEQ_PATH"
        exit 1
    fi
    
    log_success "Import process completed!"
    log_info "Next steps:"
    log_info "1. Review the imported posts in $BLOG_CONTENT_DIR"
    log_info "2. Add appropriate hero images to $BLOG_ASSETS_DIR"
    log_info "3. Run 'pnpm dev' to preview your blog"
}

# Run main function with all arguments
main "$@"
