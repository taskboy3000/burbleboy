# Burbleboy / taskboy3000 Manual

Burbleboy is a fork of Plerd, a static blog generator focused on incremental publishing. Rebuild only what changed instead of reprocessing 1200+ files.

## Overview

Burbleboy generates a static site from Markdown posts and plain-text notes. It uses Template Toolkit for layout, Text::MultiMarkdown for Markdown, and a per-file JSON meta system for incremental builds.

Key features:
- Incremental publishing via `--publish-new`
- Per-file `.meta.json` state in `_burbleboy/` subdirectory
- Plain Perl functions, no Moo/OOP
- Whitelist HTML sanitizer
- File locking to prevent concurrent runs
- Cron-driven CLI

## Installation

```bash
git clone https://github.com/jjohn/burbleboy_taskboy3000.git
cd burbleboy_taskboy3000
cpanm --installdeps .
```

Run from checkout directory. No system-wide install required.

Verify:
```bash
make test
```

## Configuration

Create config with:
```bash
bin/burbleboycmd --init
```

Creates `~/.burbleboy.conf` and `~/burbleboy/source` + `~/burbleboy/docroot`.

Config file is YAML. Example:
```yaml
base_uri: https://www.example.com/
title: My Blog
author_name: Your Name
author_email: you@example.com
source_path: /home/you/Dropbox/burbleboy/source
publication_path: /home/you/Sites/www
show_max_posts: 5
```

Required keys:
- `base_uri` — must start with http:// or https://
- `title`
- `author_name`
- `author_email`
- `source_path` — directory with .md posts
- `publication_path` — output directory

Optional keys:
- `source_notes_path` — defaults to `<source_path>/notes`
- `show_max_posts` — default 5
- `webmention_endpoint`
- `enable_replies` — true to show webmention UI
- `site_description`
- `jumbotron_image` — URL for front page banner
- `template_path` — custom TT templates

Backward compatibility: `_path` suffix auto-mapped to `_directory`.

View config:
```bash
bin/burbleboycmd --show-conf
```

## First Run

```bash
bin/burbleboycmd --init
bin/burbleboycmd --publish-all
```

## Source Formats

### Posts .md

Filename: `YYYYymmDDd_HHhMMmSS-slug.md` or legacy `YYYY-MM-DD-slug.md`

Headers at top, blank line before body:
```markdown
title: My Post Title
tags: perl, blogging, web
time: 2024-01-15 10:30:00
guid: optional-explicit-guid
published_filename: optional-custom-output-filename.html
publish_at: 2024-01-20 09:00:00

Body in Markdown...
```

Supported metadata: `title`, `time`, `tags`, `guid`, `published_filename`, `publish_at`.

`time` uses W3CDTF or `YYYY-MM-DD HH:MM:SS`. Falls back to filename timestamp then file mtime.

`publish_at` schedules future posts. Skipped until current time passes.

Markdown: Text::MultiMarkdown with fenced code blocks ```perl ...```. Typography: straight quotes → curly, --- → em-dash, -- → en-dash, ... → ellipsis.

HTML is sanitized via whitelist.

Unicode is preserved.

### Notes .txt

No headers. Body starts on line 1.

```
-> https://example.com/original-post
^ https://example.com/liked-post

Note body with #hashtags and https://autolinked.urls
```

- `->` line = in-reply-to URL
- `^` line = like-of URL
- Bare URLs auto-linked
- `#hashtags` → tag links
- Newlines → `<br>`
- Timestamp = file mtime

Output goes to `notes/` subdirectory.

## Publishing Commands

```bash
bin/burbleboycmd --publish-all          # full rebuild
bin/burbleboycmd --publish-new          # incremental, mtime based
bin/burbleboycmd --publish-only-posts
bin/burbleboycmd --publish-only-notes
bin/burbleboycmd --force                # ignore mtimes
bin/burbleboycmd --dryrun               # preview only
bin/burbleboycmd --verbose
bin/burbleboycmd --prune                # remove orphans
bin/burbleboycmd --republish FILE
```

Incremental workflow:
- Source mtime > published HTML mtime → republish
- Meta files written to `_burbleboy/*.meta.json`
- Aggregates rebuilt after changes

Typical rename:
```bash
mv old.txt new.txt
bin/burbleboycmd --prune
bin/burbleboycmd --publish-new
```

## Cron

Run every 5-10 minutes to catch Dropbox sync:
```cron
*/5 * * * * cd /path/to/burbleboy_taskboy3000 && bin/burbleboycmd --publish-new --verbose >> /tmp/burbleboy.log 2>&1
```

Lock file `.burbleboycmd.lock` prevents concurrent runs.

## Output

- `BASENAME.html` — individual post
- `NOTENAME.html` — individual note
- `blog.html` — front page
- `index.html` — symlink to blog.html
- `archive.html` — all posts
- `tags.html` — tag index
- `notes_roll.html` — notes roll
- `atom.xml` — Atom feed
- `feed.json` — JSON Feed
- `recent_notes.json` — notes feed
- `css/site.css` — stylesheet
- `js/site.js` — JavaScript

Web server must follow symlinks.

## Customizing Appearance

Stylesheet generated from `lib/Burbleboy/Template/site_css.tt`. Primary color via CSS custom property `--info`.

Edit template for persistent changes, or edit generated `publication_path/css/site.css` for one-off.

Jumbotron image set via `jumbotron_image` config key.

## Migration from Previous Install

1. Backup old install and site
2. Clone repo, install deps
3. Existing `~/.burbleboy.conf` works as-is
4. .md and .txt files compatible
5. Copy custom templates if any
6. `bin/burbleboycmd --publish-all --verbose`
7. Set up cron for `--publish-new`

## CLI Reference

Flags:
- `--init` — create config + dirs
- `--show-conf` — display config
- `--publish-all` — full rebuild
- `--publish-new` — incremental
- `--publish-only-posts`
- `--publish-only-notes`
- `--prune` — remove orphaned published files
- `--republish FILE` — republish single source
- `--force` — ignore mtimes
- `--dryrun` — preview
- `--verbose`
- `--version`
- `--help`
- `--manual` — show this manual

## Troubleshooting

- Lock error: another instance running
- Posts not appearing: check `publish_at` future date
- Missing notes: ensure `source_notes_path` correct
- Symlink issues: enable FollowSymLinks in Apache/nginx

For full details see README.md and AGENTS.md.
