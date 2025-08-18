#!/bin/bash

# setup-photo-sync.sh - Install dependencies for iCloud photo sync

set -e

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

# Check if Python and pip are installed
check_python() {
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed. Please install Python 3 first."
    fi
    
    if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
        error "pip is required but not installed. Please install pip first."
    fi
    
    log "Python 3 and pip are available"
}

# Install icloudpd
install_icloudpd() {
    log "Installing icloudpd..."
    
    # Try pip3 first, then pip
    if command -v pip3 &> /dev/null; then
        pip3 install --user icloudpd
    else
        pip install --user icloudpd
    fi
    
    log "icloudpd installed successfully"
}

# Check and suggest ImageMagick installation
check_imagemagick() {
    if command -v magick &> /dev/null; then
        log "ImageMagick is already installed"
    else
        warn "ImageMagick is not installed"
        echo "ImageMagick is recommended for:"
        echo "  - Converting HEIC files to JPEG"
        echo "  - Optimizing images for web"
        echo ""
        echo "To install ImageMagick on Ubuntu/Debian:"
        echo "  sudo apt update && sudo apt install imagemagick"
        echo ""
        echo "To install on other systems:"
        echo "  - macOS: brew install imagemagick"
        echo "  - Fedora: sudo dnf install ImageMagick"
        echo "  - Arch: sudo pacman -S imagemagick"
    fi
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    if command -v icloudpd &> /dev/null; then
        log "✓ icloudpd is installed and available"
        icloudpd --version
    else
        error "icloudpd installation failed or is not in PATH"
    fi
}

main() {
    log "Setting up iCloud photo sync dependencies..."
    
    check_python
    install_icloudpd
    check_imagemagick
    verify_installation
    
    log "Setup completed!"
    log "You can now use ./scripts/sync-photos.sh to download photos from iCloud"
    echo ""
    echo "Usage examples:"
    echo "  ./scripts/sync-photos.sh                    # Download favorites"
    echo "  ./scripts/sync-photos.sh all               # Download recent photos"
    echo "  ./scripts/sync-photos.sh \"Album Name\"      # Download specific album"
}

main "$@"
