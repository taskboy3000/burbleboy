# Burbleboy/taskboy3000

A fork of the [Plerd](https://github.com/jmacdotorg/plerd) static blog
generator.  Stripped down, simplified, focused on **incremental publishing** —
rebuild only what changed instead of reprocessing 1200+ files.

## What's Different from Classic Plerd

If you used the original Plerd (or the earlier fork), here is what changed:

| Area | Old Plerd | This Version |
|------|-----------|--------------|
| **OOP** | Moo-based classes everywhere | Plain Perl functions + hashes |
| **Orchestrator** | `lib/Plerd.pm` (1260 lines) | Removed entirely |
| **Models** | 12 per-page Model files (FrontPage, Archive, RSSFeed, etc.) | One `Burbleboy::Publish` module |
| **Typography** | 708-line SmartyPants fork | 15 lines of `s///` substitutions |
| **Cache** | YAML-based Remembrancer KV store | `stat()` mtime comparison |
| **Parallelism** | Parallel::ForkManager | None needed (fast enough) |
| **Config** | Path::Class objects, URI coercion, Moo attributes | Plain hashref + YAML::XS |
| **Config key names** | `_path` suffix (e.g. `source_path`) | `_path` → `_directory` mapped automatically |
| **HTML sanitization** | None | Whitelist-based XSS protection |
| **CLI flags** | `--init`, `--publish-all`, `--daemon` | `--init`, `--show-conf`, `--publish-all`, `--publish-new`, `--force`, `--verbose`, `--help`, `--version` |
| **Incremental mode** | Full rebuild every time | `--publish-new` only processes changed files |
| **Locking** | None | File lock via `flock` |
| **Dependencies** | ~18 CPAN modules | 10 modules (no Moo, no ForkManager, no Data::GUID, etc.) |

### What stayed the same

- **Source format**: `.md` files with YAML-like headers, `.txt` notes with `->`/`^` syntax
- **Publishing path**: Configurable, output is flat HTML files
- **Template Toolkit**: Still used for layout and page templates
- **Markdown**: Text::MultiMarkdown (with fenced code support)
- **Config location**: `~/.burbleboy.conf`
- **No daemon**: Still cron-driven CLI

## Installation

```bash
git clone https://github.com/jjohn/burbleboy_taskboy3000.git
cd burbleboy_taskboy3000
cpanm --installdeps .
```

No system-wide install — run from the checkout directory.  If you are running older versions of Burbleboy, stop the systemd service (sudo systemctl stop burbleboy; sudo systemctl disable burbleboy).

If you use plenv to manage Perl versions, `cpanm` installs modules into your
home directory.  No root needed.

Verify your setup:

```bash
make test
```

## Configuration

Run `bin/burbleboycmd --init` to create `~/.burbleboy.conf` with sensible
defaults and the `~/burbleboy/{source,docroot}` project directories.
The config file uses YAML.  Here is a complete example:

```yaml
base_uri: https://www.example.com/
title: My Blog
author_name: Your Name
author_email: you@example.com
source_path: /home/you/Dropbox/burbleboy/source
publication_path: /home/you/Sites/www
show_max_posts: 5
```

Use `bin/burbleboycmd --show-conf` to display your current configuration
(from the file or default values).

### Required keys

- `base_uri` — must start with `http://` or `https://`
- `title` — blog title
- `author_name` — your name
- `author_email` — your email
- `source_path` — directory containing `.md` post files
- `publication_path` — output directory (created if missing)

### Optional keys

- `source_notes_path` — directory containing note `.txt` files
  (defaults to `<source_path>/notes`)
- `show_max_posts` — how many posts on the front page and in JSON feed
  (default: 5)
- `webmention_endpoint` — webmention endpoint URL
- `site_description` — about-text for the sidebar (fallback: "This is a blog
  by *author_name*")
- `jumbotron_image` — URL for the front-page jumbotron background image
- `template_path` — custom Template Toolkit templates directory
  (default: `lib/Burbleboy/Template/` in the burbleboy checkout)

### Backward compatibility

Keys with a `_path` suffix (e.g. `source_path`) are automatically mapped to
`_directory` internally.  Both old and new key names work.

## Source File Format

### Posts (`.md`)

Filename convention:

```
2024y01m15d_12h34m56s-my-post-slug.md
```

The timestamp in the filename is used as the post date if no `time:` header is
present.

Metadata headers at the top of the file, separated from the body by a blank
line:

```markdown
title: My Post Title
tags: perl, blogging, web
time: 2024-01-15 10:30:00
guid: optional-explicit-guid
published_filename: optional-custom-output-filename.html

Body content in Markdown here.
```

Supported metadata keys:

| Key | Required | Description |
|-----|----------|-------------|
| `title` | No* | Post title (defaults to filename stem) |
| `time` | No* | Publication timestamp (W3CDTF or `YYYY-MM-DD HH:MM:SS` format) |
| `tags` | No | Comma-separated list |
| `guid` | No | Explicit GUID (auto-generated from source path via SHA-1) |
| `published_filename` | No | Override the output filename |

\* Title and time are strongly recommended.

Markdown processing: **Text::MultiMarkdown** with fenced code block support
(three or more backticks with optional language name):

    ```perl
    sub hello { say "world" }
    ```

Typography: straight quotes → curly, `---` → em-dash, `--` → en-dash,
`...` → ellipsis.

HTML output is sanitized via a whitelist tag filter (XSS protection).

**Unicode support**: Source `.md` files are read as UTF-8. Any Unicode
characters (emoji, accented letters, non-Latin scripts, etc.) are preserved
through the full pipeline and faithfully reproduced in the published HTML,
Atom XML, and JSON feeds.

### Notes (`.txt`)

Notes are short microposts with optional social annotations.  Unlike posts,
notes have **no YAML metadata headers** — the entire file is the body text.
Filename convention is free-form (anything `.txt` works).

```
-> https://example.com/original-post    (in-reply-to)
^ https://example.com/liked-post        (like-of)

Note body with #hashtags and https://autolinked.urls
```

- Lines starting with `->` set the in-reply-to URL
- Lines starting with `^` set the like-of URL
- Bare URLs are auto-linked
- `#hashtags` are converted to tag links
- Newlines become `<br>` in HTML output
- Timestamp is the file's modification time (no `time:` header)

### Key differences from posts

| Aspect | Posts | Notes |
|--------|-------|-------|
| **File extension** | `.md` | `.txt` |
| **Metadata headers** | YAML-style (`title:`, `tags:`, `time:`) | None — body starts on line 1 |
| **Markdown processing** | Text::MultiMarkdown (full markdown) | None — line-by-line rendering with auto-linking |
| **Typography** | Smart quotes, em-dashes, ellipses | Raw text only |
| **Output location** | `$base_uri/filename.html` | `$base_uri/notes/filename.html` |
| **Roll page** | `blog.html` | `notes_roll.html` |
| **JSON feed** | `feed.json` | `recent_notes.json` |

## Usage

```bash
# First run — create config and project directories
bin/burbleboycmd --init

# View current configuration
bin/burbleboycmd --show-conf

# Publish everything (full rebuild)
bin/burbleboycmd --publish-all

# Only publish changed files (incremental)
bin/burbleboycmd --publish-new

# Force republish even if source hasn't changed
bin/burbleboycmd --publish-all --force

# Publish only posts or only notes
bin/burbleboycmd --publish-only-posts
bin/burbleboycmd --publish-only-notes

# Verbose output
bin/burbleboycmd --publish-new --verbose

# Help
bin/burbleboycmd --help
```

Run `bin/burbleboycmd --init` first if you have not set up the config yet.
Then run every 5–10 minutes to catch newly synced Dropbox files.  This gives
Dropbox enough time to finish syncing before burbleboy reads the source
directory (running every minute risks catching partially-synced files).

```cron
# Every 5 minutes
*/5 * * * * cd /path/to/burbleboy_taskboy3000 && bin/burbleboycmd --publish-new --verbose >> /tmp/burbleboy.log 2>&1

# Or every 10 minutes
*/10 * * * * cd /path/to/burbleboy_taskboy3000 && bin/burbleboycmd --publish-new --verbose >> /tmp/burbleboy.log 2>&1
```

## Output

| File | Content |
|------|---------|
| `BASENAME.html` | Individual post (per source file) |
| `NOTENAME.html` | Individual note |
| `blog.html` | Front page (latest N posts) |
| `archive.html` | All posts sorted by date |
| `tags.html` | Tag index grouped by first letter |
| `notes_roll.html` | Notes roll |
| `atom.xml` | Atom feed (all posts) |
| `feed.json` | JSON Feed (top N posts) |
| `recent_notes.json` | JSON Feed for notes |
| `css/site.css` | Generated site stylesheet |
| `js/site.js` | Generated site JavaScript (feed loading, webmentions) |

## Customizing the Appearance

The site stylesheet is generated from `lib/Burbleboy/Template/site_css.tt`.
The primary color is controlled via a CSS custom property:

```css
:root {
    --info: #23397f;       /* primary color for nav, headers, links */
    --header-spacing: 0.05em;
    --light: #ddd;         /* light text on dark backgrounds */
}
```

To change the theme color, either:

1. **Edit the generated file** (`publication_path/css/site.css`) directly
   (changes persist across publishes unless you run `--publish-all`).
2. **Edit the template** (`lib/Burbleboy/Template/site_css.tt`) to customize
   the source — changes apply on every subsequent publish.

### Jumbotron background image

Set `jumbotron_image` in `~/.burbleboy.conf` to a URL to use a background
image on the front page:

```yaml
jumbotron_image: https://www.example.com/images/header.jpg
```

## Migration from a Previous Install

1. **Back up your old Burbleboy install and published site**.
2. Clone this repo and install dependencies.
3. Your existing `~/.burbleboy.conf` should work as-is.  If you want a fresh
   start, run `bin/burbleboycmd --init`.
4. Your `.md` post files and `.txt` note files are compatible.  No changes
   needed.
5. The built-in Template Toolkit templates are the same Bootstrap 5 layout.
   If you customized templates, copy them from your old install.
6. Run `bin/burbleboycmd --publish-all --verbose` to rebuild your entire site.
7. Set up a cron job for incremental publishing:
   `bin/burbleboycmd --publish-new`.

## Author

Joe Johnston <jjohn@taskboy.com>

Forked from Jason McIntosh's [Plerd](https://github.com/jmacdotorg/plerd).
