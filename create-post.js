#!/usr/bin/env node
/**
 * create-post.js — generate a new .mdx blog post
 * Usage: node create-post.js "My Post Title" "Post body text here"
 */

import fs from 'fs'
import path from 'path'

const [, , titleArg, bodyArg] = process.argv
if (!titleArg) {
	console.error('❌  Usage: node create-post.js "Title" "Body text"')
	process.exit(1)
}

const title = titleArg.trim()
const body = (bodyArg || '').trim() || 'Write something inspiring here...'
const slug = title
	.toLowerCase()
	.replace(/[^a-z0-9]+/g, '-')
	.replace(/^-|-$/g, '')
const date = new Date().toISOString()

const frontmatter = `---\nheroImage: /images/podcast/hero-image.png\ncategory: Music\ndescription: ${title}\npubDate: ${date}\ntags:\n  - synth\n  - blog\n  - auto\n  - telegram\ntitle: ${title}\ndraft: false\n---\n`

const content = `${frontmatter}\n${body}\n`
const targetDir = path.join(process.cwd(), 'src', 'content', 'blog')
const filename = `${slug}.mdx`
const filePath = path.join(targetDir, filename)

fs.writeFileSync(filePath, content, 'utf8')
console.log(`✅  Created new post: ${filePath}`)
