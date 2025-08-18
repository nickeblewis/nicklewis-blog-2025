# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## About This Project

This is a personal blog built with Astro, featuring content management through Tina CMS. The blog focuses on web development, photography, music, and personal journal entries. The site is configured to be deployed to Netlify and supports both Markdown and MDX content formats.

## Development Commands

### Core Development

- `pnpm install` - Install all dependencies
- `pnpm dev` - Start development server with Tina CMS at localhost:3000
- `pnpm start` - Start Astro dev server only (without Tina CMS)
- `pnpm build` - Build production site to `./dist/` (includes Pagefind search index generation)
- `pnpm preview` - Preview production build locally

### Code Quality

- `pnpm lint` - Run ESLint on all files
- `pnpm format` - Format code with Prettier
- `pnpm format:check` - Check code formatting without changes
- `pnpm sync` - Generate TypeScript types for Astro modules

### CMS Development

- The main development command (`pnpm dev`) starts Tina CMS alongside Astro
- Tina CMS admin interface is available at `/admin` when running in development
- CMS configuration is in `tina/config.ts`

## Architecture Overview

### Technology Stack

- **Framework**: Astro 5.13.2 with TypeScript
- **Styling**: Tailwind CSS with custom configuration
- **Content**: Astro Content Collections with Zod validation
- **CMS**: Tina CMS for content management
- **Search**: Pagefind for static site search
- **Package Manager**: pnpm (preferred)

### Project Structure

#### Content Management

- `src/content/blog/` - Blog posts in Markdown/MDX format
- `src/content/config.ts` - Content collection schemas with Zod validation
- `tina/config.ts` - Tina CMS configuration

#### Configuration & Data

- `src/data/site.config.ts` - Main site configuration (author, title, URL, pagination)
- `src/data/categories.ts` - Available blog post categories (Journal, Coding, Music, Photography, Crypto, History)
- `src/data/links.ts` - Social media and external links

#### Components & Layouts

- `src/components/` - Reusable Astro components for UI elements
- `src/layouts/` - Page layouts (BaseLayout.astro, BlogPost.astro)
- Components include: PostCard, Pagination, Search, TableOfContents, Share, ToggleTheme

#### Utilities & Helpers

- `src/utils/` - Utility functions for posts, reading time calculation, slugification
- TypeScript path aliases configured in `tsconfig.json` for clean imports

### Content Schema

Blog posts require:

- `title` (max 80 characters)
- `description`
- `pubDate` (Date)
- `heroImage` (image file)
- `category` (from predefined categories)
- `tags` (array of strings)
- `draft` (boolean, defaults to false)

### Key Features

- Dark/light theme toggle
- Static search with Pagefind
- Related posts functionality
- Reading time estimation
- Social sharing capabilities
- RSS feed generation
- Responsive design with mobile-first approach
- Draft mode for unpublished content
- Table of contents generation

### Build Process

1. Astro builds the static site
2. Pagefind generates search index (`postbuild` script)
3. Site is ready for deployment to static hosting

### Development Notes

- Site configuration includes pagination size (6 posts per page)
- Uses Material Theme Palenight for syntax highlighting
- Custom Tailwind configuration with Manrope font family
- Image optimization handled by Astro's passthrough service
- Supports both `.md` and `.mdx` file formats for content

### Important File Locations

- Blog content: `src/content/blog/`
- Site assets: `src/assets/images/`
- Public assets: `public/`
- Configuration files in root and `src/data/`
