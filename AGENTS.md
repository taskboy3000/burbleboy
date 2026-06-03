# Burbleboy/taskboy3000 — AI Agent Index Map

Fork of [Plerd](https://github.com/jmacdotorg/plerd) static blog generator.
**Core differentiator**: Incremental publishing — rebuild only what changed instead
of reprocessing 1200+ files. Full rewrite completed: no Moo, no SmartyPants,
no Remembrancer, no ForkManager, no per-page models.

The codebase works and is deployed. All "target for rewrite" plans have been
executed. See `burbleboy-incremental-state-design.md` for the incremental state
design decisions that led to the current architecture.

## Tech Stack

| Layer | Tool |
|-------|------|
| Lang | Perl 5.28+ |
| Style | Functional (Exporter-based, no OOP/Moo) |
| CLI | Getopt::Long |
| Markdown | Text::MultiMarkdown + custom fenced-code subclass |
| Templates | Template Toolkit (`.tt` files) |
| Config | YAML::XS (`~/.burbleboy.conf`), `_path` → `_directory` auto-mapped |
| State | Per-file `.meta.json` in `_burbleboy/` subdirectory (no DB, no YAML cache) |
| XSS | Whitelist-based HTML sanitizer in `Sanitize.pm` (46 lines) |
| Locking | `flock` on a `.burbleboycmd.lock` file in publication dir |
| Frontend | Bootstrap 5, highlight.js, vanilla JS |
| Dependencies | 10 CPAN modules (see `cpanfile`) |

## Directory Layout

```
bin/burbleboycmd                   ← CLI entry point (201 lines)
lib/Burbleboy/
  Config.pm                        ← Config read/validate (224 lines)
  Publish.pm                       ← ALL publish + aggregate logic (1037 lines)
  Markdown.pm                      ← MMD subclass for fenced code blocks (63 lines)
  Sanitize.pm                      ← XSS whitelist HTML filter (46 lines)
  Model/
    Post.pm                        ← Post parser (.md files) (345 lines)
    Note.pm                        ← Note parser (.txt files) (150 lines)
  Template/
    layout.tt, single_post.tt      ← Single post + master layout
    front_page.tt, archive.tt      ← Aggregate pages
    notes_roll.tt, note.tt         ← Notes
    feed.tt, tags.tt               ← Feeds + tag index
    site_css.tt, site_js.tt        ← Generated assets
    config_file.tt                 ← `--init` template
    _post.tt, _note.tt             ← Partial templates
t/                                 ← 20+ test files (see test section below)
burbleboy-incremental-state-design.md  ← Design doc for meta file system
```

## Key Architecture: The Meta File System

Since a full parse + Markdown render of 1200 posts takes ~3 minutes, the
incremental publish needs a persisted index. The chosen approach (Option D in
the design doc) is per-file JSON metadata alongside published HTML:

```
publication_dir/
  _burbleboy/
    2024y01m15d_12h00m00s-post.html.meta.json
    2024y01m16d_14h00m00s-post2.html.meta.json
    ...
```

- **`write_meta()`** — called after each `publish_post()` / `publish_note()`.
  Writes `{ title, date, uri, tags, body_html, reading_time, id, ... }` to
  `$pub_dir/_burbleboy/$filename.meta.json` via tempfile + atomic rename.
- **`read_all_meta()`** — scans `_burbleboy/` via `File::Find`, decodes each
  `.meta.json`, reconstructs DateTime objects + expanded tags. Used by all
  aggregate page generators.
- **`fill_body_for_posts()` / `fill_body_for_top_n()`** — reads body HTML back
  from published `.html` files when post hashrefs lack `body_html` (e.g. when
  meta was read from disk without body extracted). Used for front page (top N)
  and feeds (all posts).
- **`extract_body_from_html()`** — regex-based body extraction from rendered
  HTML, using `<!-- POST_BODY_START -->` / `<!-- POST_BODY_END -->` comment
  markers, with fallback to `<div class="body e-content">`.

## Data Flow

### Incremental publish (`--publish-new`)

```
Source .md file changed (mtime > published .html mtime)
  → Publish::incremental_publish_posts() scans source_dir
  → Post::parse_post() returns hashref
  → Publish::publish_post() renders via TT, writes .html
  → Publish::write_meta() writes _burbleboy/BASENAME.html.meta.json
  → Publish::run_publish() calls read_all_meta() to get full post list
  → Rebuilds all aggregate pages (blog.html, archive, tags, atom, json feeds)
```

### Full rebuild (`--publish-all`)

```
Publish::_publish_posts()
  → Parses ALL .md files, publishes each
  → Writes meta files alongside each
  → Then calls aggregates with the full post list
```

### Note flow (same pattern, parallel path)

```
Source .txt file changed
  → Note::parse_note() — no YAML headers, line-based rendering
  → Publish::publish_note() writes notes/BASENAME.html
  → write_meta() for notes too (with 'note' type field)
  → Aggregates: notes_roll.html, recent_notes.json
```

## Aggregate Pages (what each needs)

| Aggregate | Body HTML? | DateTime obj? | Source in Publish.pm |
|-----------|-----------|---------------|----------------------|
| `blog.html` (front page) | YES | YES | `publish_front_page()` |
| `archive.html` | no | no | `publish_archive_page()` |
| `tags.html` | no | no | `publish_tags_index()` |
| `atom.xml` | YES | no | `publish_atom_feed()` |
| `feed.json` | YES | no | `publish_json_feed()` |
| `notes_roll.html` | YES | no | `publish_notes_roll()` |
| `recent_notes.json` | YES | no | `publish_notes_json()` |
| `css/site.css` | — | — | `publish_site_css()` |
| `js/site.js` | — | — | `publish_site_js()` |

## CLI Interface (`bin/burbleboycmd`)

| Flag | Description |
|------|-------------|
| `--init` | Create `~/.burbleboy.conf` + project directories |
| `--show-conf` | Display current config |
| `--publish-all` | Full rebuild: parse + publish ALL source files |
| `--publish-new` | Incremental: only files where source mtime > published mtime |
| `--publish-only-posts` | Only posts, skip notes |
| `--publish-only-notes` | Only notes, skip posts |
| `--force` | Ignore mtimes, republish even if up-to-date |
| `--dryrun` | Show what would happen without writing |
| `--verbose` | Detailed progress output |
| `--version` | Print version |
| `--help` | Usage text |

The CLI acquires a `flock`-based lock before publishing to prevent concurrent
runs (cron + manual). Lock file lives at `$publication_dir/.burbleboycmd.lock`.

## Source Formats

### Posts (`.md`)

Filename convention: `YYYYymmDDd_HHhMMmSS-slug.md` (new) or `YYYY-MM-DD-slug.md` (legacy)

```
title: My Post Title
tags: perl, blogging, web
time: 2024-01-15 10:30:00
guid: optional-explicit-guid
published_filename: optional-custom-output-filename.html

Body content in Markdown...
```

Headers are hand-parsed (no YAML module in the header block). The `time` header
uses W3CDTF format. Falls back to filename timestamp, then file mtime.

Support metadata: `title`, `time`, `tags`, `guid`, `published_filename`.

### Notes (`.txt`)

No YAML headers — file starts directly with body.

```
-> https://example.com/original-post    (in-reply-to)
^ https://example.com/liked-post        (like-of)

Note body with #hashtags and https://autolinked.urls
```

- `->` lines set in-reply-to URL (microformats `u-in-reply-to`)
- `^` lines set like-of URL (microformats `u-like-of`)
- Bare URLs auto-linked
- `#hashtags` converted to tag links
- Newlines become `<br>`
- Timestamp is file mtime

## Unique Deviations from Plerd (completed rewrites)

| Area | Original Plerd | Current Burbleboy |
|------|---------------|-------------------|
| **OOP** | Moo classes | Plain functions + hashrefs |
| **Orchestrator** | `lib/Plerd.pm` (1260 lines) | Removed entirely |
| **Models** | 12 per-page model files | One `Publish.pm` module |
| **Typography** | 708-line SmartyPants fork | 15 lines of `s///` in Post.pm |
| **Cache** | YAML-based Remembrancer KV store | `stat()` mtime + `_burbleboy/*.meta.json` |
| **Parallelism** | Parallel::ForkManager | None needed |
| **HTML sanitization** | None | Whitelist-based (`Sanitize.pm`) |
| **Locking** | None | `flock`-based file lock |

## Test Structure

Run with: `make test` or `t/.runtests.pl t/NAME.t`

| File | What it tests |
|------|---------------|
| `000-compile.t` | All modules compile |
| `001-test-helper.t` | TestHelper (setup/teardown temp sites) |
| `010-init.t` | Config initialization |
| `013-notes.t` | Note parsing |
| `050-post.t` | Post model parsing |
| `051-model-utc-date.t` | DateTime handling in posts |
| `055-template-delimiters.t` | TT template config |
| `056-template-stash-uris.t` | URI generation in template stash |
| `060-publish-post.t` | Single post publish |
| `061-publish-note.t` | Single note publish |
| `062-meta-file.t` | Meta file write/read |
| `063-meta-read.t` | `read_all_meta()` |
| `064-body-extract.t` | `extract_body_from_html()` |
| `065-tags-compat.t` | Tag processing |
| `070-aggregates.t` | Aggregate page generation |
| `070-production-baseline.t` | Production baseline comparison |
| `071-tags-page.t` | Tags index page |
| `080-feeds.t` | Atom + JSON feed generation |
| `081-notes-feeds.t` | Notes feed generation |
| `090-cli.t` | CLI flag handling |
| `091-incremental.t` | Incremental publish |
| `092-incremental-aggregates.t` | Incremental + aggregates |
| `093-incremental-meta-integration.t` | Meta file interaction with incremental |
| `095-sanitize.t` | HTML sanitizer |
| `100-burbleboy.t` | Full integration (compares output to `t/baselines/`) |

Baselines are in `t/baselines/new-site/docroot/` — checked into git. Compared
by stripping pub dates from filenames and checking content size diff ≤ 10 bytes.

## CI (GitHub Actions)

A workflow at `.github/workflows/test.yml` runs the full test suite on every
push to `main` and every pull request.  Currently targets Perl 5.28.

Before pushing, always run:

    make test

All tests must pass.  The CI will catch regressions, but local verification
keeps the commit history clean.

## Config (`~/.burbleboy.conf`)

Required keys: `base_uri`, `title`, `author_name`, `author_email`,
`source_path`, `publication_path`.

Optional keys: `source_notes_path`, `show_max_posts` (default 5),
`webmention_endpoint`, `enable_replies`, `site_description`,
`jumbotron_image`, `template_path`.

Backward compatibility: keys with `_path` suffix are auto-mapped to `_directory`.

## Key Patterns

- `use Modern::Perl '2018'` at top of every file
- `eval { ... } or do { ... }` / `eval { ... }; if ( $@ )` for error handling
- Functions exported via `Exporter` with `@EXPORT_OK` + `%EXPORT_TAGS`
- Config accessed as a plain hashref (`$config->{ key }`)
- Template Toolkit with INCLUDE_PATH set to `lib/Burbleboy/Template/`
- Post headers hand-parsed line-by-line (not via a YAML module)
- Note lines parsed with regex for `->`, `^`, `#`, bare URLs
- Webmention: client-side JS only (no server-side processing)
- No daemon mode — cron-driven CLI (`*/5 * * * * bin/burbleboycmd --publish-new`)
