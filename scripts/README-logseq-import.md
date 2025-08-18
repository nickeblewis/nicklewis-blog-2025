# Logseq Import Script

This script allows you to import pages from Logseq and convert them into blog posts for your Astro blog.

## Features

- ✅ Converts Logseq Markdown pages to blog posts with proper frontmatter
- ✅ Extracts titles from H1 headers or uses filenames
- ✅ Generates descriptions from first paragraph
- ✅ Handles Logseq-style tags (#tag) and converts them
- ✅ Processes both standard markdown images `![alt](path)` and Logseq-style `[[image.jpg]]`
- ✅ Copies and renames images to the blog's assets directory
- ✅ Configurable category mapping and tag processing
- ✅ Dry-run mode to preview what would be imported
- ✅ Verbose logging for troubleshooting
- ✅ Handles existing file conflicts with user confirmation
- ✅ Supports filtering files by regex patterns

## Quick Start

1. **Make the script executable** (if not already done):

   ```bash
   chmod +x scripts/import-from-logseq.sh
   ```

2. **Basic import from Logseq export directory**:

   ```bash
   ./scripts/import-from-logseq.sh /path/to/logseq/export
   ```

3. **Import a single file as a draft**:

   ```bash
   ./scripts/import-from-logseq.sh /path/to/page.md --draft
   ```

4. **Preview what would be imported (dry run)**:
   ```bash
   ./scripts/import-from-logseq.sh /path/to/logseq/export --dry-run --verbose
   ```

## Usage Examples

### Import all pages as "Coding" category posts

```bash
./scripts/import-from-logseq.sh /path/to/logseq/export -c Coding -t "programming,tutorial"
```

### Import only specific files matching a pattern

```bash
./scripts/import-from-logseq.sh /path/to/logseq/export -f "blog|post" -e "private|temp"
```

### Import with custom configuration

```bash
# Create your config file first
cp scripts/logseq-import.config.example scripts/logseq-import.config
# Edit the config file, then run:
./scripts/import-from-logseq.sh /path/to/logseq/export
```

## Command Line Options

| Option             | Description                             | Example                              |
| ------------------ | --------------------------------------- | ------------------------------------ |
| `-c, --category`   | Set default category for imported posts | `-c Coding`                          |
| `-d, --draft`      | Import all posts as drafts              | `--draft`                            |
| `-h, --hero-image` | Default hero image path                 | `-h ../../assets/images/my-hero.jpg` |
| `-t, --tags`       | Comma-separated default tags            | `-t "imported,logseq"`               |
| `-f, --filter`     | Only import files matching pattern      | `-f "blog\|post"`                    |
| `-e, --exclude`    | Exclude files matching pattern          | `-e "private\|temp"`                 |
| `--dry-run`        | Preview without making changes          | `--dry-run`                          |
| `--verbose`        | Enable detailed output                  | `--verbose`                          |
| `--help`           | Show help message                       | `--help`                             |

## Configuration File

Create a configuration file at `scripts/logseq-import.config` to customize the import behavior:

```bash
# Copy the example config
cp scripts/logseq-import.config.example scripts/logseq-import.config
```

### Available Configuration Options

```bash
# Default category for imported posts
DEFAULT_CATEGORY="Journal"

# Default hero image path
DEFAULT_HERO_IMAGE="../../assets/images/default-hero.jpg"

# Default draft status
DEFAULT_DRAFT=false

# Map Logseq tags to blog categories
CATEGORY_MAPPING="programming:Coding,dev:Coding,music:Music,photo:Photography"

# Rename tags during import
TAG_MAPPING="js:javascript,ts:typescript,react:reactjs"

# Default tags to add to all imports
DEFAULT_TAGS="logseq,imported"
```

## How It Works

### 1. Content Processing

- **Title Extraction**: Looks for the first H1 header (`# Title`), falls back to filename
- **Description**: Uses the first paragraph after the title (max 200 chars)
- **Tags**: Extracts Logseq-style tags (`#tag`) and converts them to lowercase
- **Slug Generation**: Creates URL-friendly slugs from titles

### 2. Image Handling

The script processes multiple image formats:

**Standard Markdown Images**: `![alt text](path/to/image.jpg)`

- Copies image to `src/assets/images/`
- Updates reference to use relative path
- Renames to avoid conflicts

**Logseq-Style Images**: `[[image.jpg]]` or `![[image.jpg]]`

- Converts to standard markdown format
- Copies and renames images
- Preserves alt text where possible

### 3. Logseq-Specific Processing

- **Block References**: `{{block-reference}}` → `<!-- Block reference removed -->`
- **Wiki Links**: Preserved as-is (can be processed further if needed)
- **Properties**: Frontmatter properties are ignored (blog uses its own)

## File Structure

After running the script, your blog will have:

```
src/
├── content/blog/
│   ├── imported-post-title.mdx
│   └── another-logseq-page.mdx
└── assets/images/
    ├── imported-1645123456-1.jpg
    └── logseq-image-imported.png
```

## Frontmatter Generated

Each imported post gets this frontmatter:

```yaml
---
heroImage: ../../assets/images/default-hero.jpg
category: Journal
description: First paragraph of the content or "Imported from Logseq"
pubDate: 2025-01-18T14:30:00.000Z
tags:
  - extracted-tag
  - imported
title: Page Title
draft: false # Only if imported as draft
---
```

## Available Categories

The script validates against these blog categories:

- Journal
- Coding
- Music
- Photography
- Crypto
- History

## Troubleshooting

### Common Issues

1. **"Blog content directory not found"**
   - Make sure you're running the script from the project root
   - Check that `src/content/blog/` exists

2. **"Invalid category"**
   - Use one of the valid categories listed above
   - Check your configuration file syntax

3. **Images not found**
   - Ensure image paths in Logseq are relative to the markdown file
   - Use `--verbose` to see detailed image processing

4. **Permission errors**
   - Make sure the script is executable: `chmod +x scripts/import-from-logseq.sh`
   - Check write permissions for the blog directories

### Debug Mode

Use verbose mode to see detailed processing:

```bash
./scripts/import-from-logseq.sh /path/to/logseq --verbose --dry-run
```

This will show:

- Which files are being processed
- Title, description, and tags extracted
- Image processing details
- Preview of generated frontmatter

## Integration with Your Workflow

### Typical Workflow

1. Export pages from Logseq to a directory
2. Run the import script with `--dry-run` first
3. Review what would be imported
4. Run the actual import
5. Review generated posts in `src/content/blog/`
6. Add proper hero images if needed
7. Run `pnpm dev` to preview your blog

### Selective Importing

You might want to import different types of content differently:

```bash
# Import coding-related posts
./scripts/import-from-logseq.sh /path/to/logseq -f "programming|code|tutorial" -c Coding

# Import journal entries
./scripts/import-from-logseq.sh /path/to/logseq -f "journal|daily" -c Journal --draft

# Import music-related posts
./scripts/import-from-logseq.sh /path/to/logseq -f "music|album|song" -c Music
```

This approach allows you to organize your Logseq content into appropriate blog categories.
