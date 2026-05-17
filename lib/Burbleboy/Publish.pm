package Burbleboy::Publish;
use Modern::Perl '2018';

use Exporter qw(import);
use File::Basename qw(basename);
use File::Spec;
use Burbleboy::Sanitize qw(sanitize_html);

use URI;

our @EXPORT_OK = qw(
    publish_post publish_note needs_update
    publish_front_page publish_archive_page
    publish_tags_index
    publish_atom_feed publish_json_feed
    publish_notes_roll publish_notes_json
    publish_site_css publish_site_js
    incremental_publish_posts incremental_publish_notes
    try_publish write_meta read_all_meta
    extract_body_from_html fill_body_for_posts fill_body_for_top_n
);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub needs_update {
    my ( $source_file, $output_file ) = @_;

    return 1 unless -e $output_file;

    my @source_stat = stat( $source_file ) or return 1;
    my @output_stat = stat( $output_file ) or return 1;

    return $source_stat[ 9 ] > $output_stat[ 9 ];
}

sub _build_template_stash {
    my ( $config, $this_uri ) = @_;

    my $base_uri = $config->{ base_uri } || 'http://localhost/';
    $base_uri =~ s{/$}{};

    my $site_desc = $config->{ site_description } || '';
    unless ( $site_desc ) {
        my $author = $config->{ author_name }  || 'Unknown Author';
        my $email  = $config->{ author_email } || '';
        $site_desc = "This is a blog by $author";
        $site_desc .= " (<a href=\"mailto:$email\">$email</a>)" if $email;
        $site_desc .= '.';
    }

    return {
        frontPage       => { uri => 'blog.html' },
        notesRoll       => { uri => 'notes_roll.html' },
        archive         => { uri => 'archive.html' },
        tagsIndex       => { uri => 'tags.html' },
        rssFeed         => { uri => 'atom.xml' },
        jsonFeed        => { uri => URI->new( './feed.json' ) },
        notesJSONFeed   => { uri => URI->new( './recent_notes.json' ) },
        siteCSS         => { uri => 'css/site.css' },
        siteJS          => { uri => 'js/site.js' },
        siteDescription => $site_desc,
        w3validatorURI  => URI->new( 'https://validator.w3.org/nu/' ),
        thisURI         => $this_uri || URI->new( "$base_uri/" ),
    };
}

sub publish_post {
    my ( $source_file, $config, $tt ) = @_;

    die "Source file not found: $source_file" unless -e $source_file;

    require Burbleboy::Model::Post;
    my $post = Burbleboy::Model::Post::parse_post( $source_file, $config );

    $post->{ body_html } = sanitize_html( $post->{ body_html } );
    $post->{ body }      = $post->{ body_html };

    write_meta( $post, $config, 'post' );

    $post->{ tags } = _expand_tags( $post->{ tags }, $config->{ base_uri } );

    my $output;
    my $stash = _build_template_stash( $config, $post->{ uri } );
    $tt->process(
        'single_post.tt',
        {   %$stash,
            post          => $post,
            config        => $config,
            activeSection => 'blog'
        },
        \$output
    ) or die $tt->error();

    my $pub_file = $post->{ publication_file };
    open my $fh, '>:utf8', $pub_file or die "Cannot write $pub_file: $!";
    print $fh $output;
    close $fh;

    return $post;
}

sub publish_note {
    my ( $source_file, $config, $tt ) = @_;

    die "Source file not found: $source_file" unless -e $source_file;

    require Burbleboy::Model::Note;
    my $note = Burbleboy::Model::Note::parse_note( $source_file, $config );

    $note->{ body_html } = sanitize_html( $note->{ body_html } );

    write_meta( $note, $config, 'note' );

    my $output;
    my $stash = _build_template_stash( $config, $note->{ uri } );
    $tt->process(
        'note.tt',
        {   %$stash,
            note          => $note,
            config        => $config,
            activeSection => 'notes_roll'
        },
        \$output
    ) or die $tt->error();

    my $pub_file = $note->{ publication_file };
    my $pub_dir  = File::Basename::dirname( $pub_file );
    mkdir $pub_dir unless -d $pub_dir;
    open my $fh, '>:utf8', $pub_file or die "Cannot write $pub_file: $!";
    print $fh $output;
    close $fh;

    return $note;
}

sub publish_front_page {
    my ( $config, $tt, $posts ) = @_;

    $posts //= [];
    my @sorted = sort { $b->{ date } cmp $a->{ date } } @$posts;
    my $max    = $config->{ show_max_posts } || 5;
    my @shown  = @sorted > $max ? @sorted[ 0 .. $max - 1 ] : @sorted;

    my $output;
    my $stash = _build_template_stash( $config );
    $tt->process(
        'front_page.tt',
        {   %$stash,
            posts         => \@shown,
            config        => $config,
            section_title => 'Latest Articles',
            activeSection => 'blog',
        },
        \$output
    ) or die $tt->error();

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    open my $fh, '>:utf8', "$pub_dir/blog.html"
        or die "Cannot write blog.html: $!";
    print $fh $output;
    close $fh;

    my $index_file = "$pub_dir/index.html";
    if ( -l $index_file || !-e $index_file ) {
        unlink $index_file if -l $index_file;
        symlink 'blog.html', $index_file
            or warn "Cannot create index.html symlink: $!";
    }

    return 1;
}

sub _note_fallback_title {
    my ( $note ) = @_;
    my $body = $note->{ body } || '';
    $body =~ s/^\s+//;
    $body =~ s/\s+$//;
    my ( $first ) = $body =~ /^(.{1,80})/;
    return defined $first ? "$first..." : '(untitled note)';
}

sub publish_tags_index {
    my ( $config, $tt, $posts, $notes ) = @_;

    $posts //= [];
    $notes //= [];
    my %tag_links;
    for my $post ( @$posts ) {
        my $tags = $post->{ tags } or next;
        for my $tag ( @$tags ) {
            my $tag_name = ref $tag ? $tag->{ name } : $tag;
            my $normalized =
                ref $tag
                ? ( $tag->{ normalized_name } || lc( $tag->{ name } ) )
                : lc( $tag_name );
            my $letter = uc( substr( $normalized, 0, 1 ) );
            $letter = 'Z' if $letter !~ /^[A-Z]$/;
            push @{ $tag_links{ $letter }{ $normalized } },
                { uri => $post->{ uri }, title => $post->{ title } };
        }
    }
    for my $note ( @$notes ) {
        my $tags = $note->{ tags } or next;
        for my $tag ( @$tags ) {
            my $tag_name = ref $tag ? $tag->{ name } : $tag;
            my $normalized =
                ref $tag
                ? ( $tag->{ normalized_name } || lc( $tag->{ name } ) )
                : lc( $tag_name );
            my $letter = uc( substr( $normalized, 0, 1 ) );
            $letter = 'Z' if $letter !~ /^[A-Z]$/;
            push @{ $tag_links{ $letter }{ $normalized } },
                {
                uri   => $note->{ uri },
                title => $note->{ title } || _note_fallback_title( $note )
                };
        }
    }

    my $output;
    my $stash = _build_template_stash( $config );
    $tt->process(
        'tags.tt',
        {   %$stash,
            tag_links     => \%tag_links,
            config        => $config,
            activeSection => 'tags'
        },
        \$output
    ) or die $tt->error();

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    open my $fh, '>:utf8', "$pub_dir/tags.html"
        or die "Cannot write tags.html: $!";
    print $fh $output;
    close $fh;
    return 1;
}

sub publish_archive_page {
    my ( $config, $tt, $posts ) = @_;

    $posts //= [];
    my @sorted = sort { $a->{ date } cmp $b->{ date } } @$posts;

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    my $output;
    my $stash = _build_template_stash( $config );
    $tt->process(
        'archive.tt',
        {   %$stash,
            posts         => \@sorted,
            config        => $config,
            activeSection => 'archive'
        },
        \$output
    ) or die $tt->error();

    open my $fh, '>:utf8', "$pub_dir/archive.html"
        or die "Cannot write archive.html: $!";
    print $fh $output;
    close $fh;
    return 1;
}

sub publish_atom_feed {
    my ( $config, $tt, $posts ) = @_;

    $posts //= [];
    my @sorted = sort { $b->{ date } cmp $a->{ date } } @$posts;

    require DateTime;
    require DateTime::Format::W3CDTF;
    my $parser    = DateTime::Format::W3CDTF->new;
    my $now_dt    = DateTime->now( time_zone => 'local' );
    my $timestamp = $parser->format_datetime( $now_dt );

    my @feed_posts;
    for my $post ( @sorted ) {
        push @feed_posts,
            {
            title               => $post->{ title },
            uri                 => $post->{ uri },
            published_timestamp => $post->{ date },
            updated_timestamp   => $post->{ date },
            body                => $post->{ body_html },
            };
    }

    my $output;
    $tt->process(
        'feed.tt',
        { posts => \@feed_posts, config => $config, timestamp => $timestamp },
        \$output
    ) or die $tt->error();

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    open my $fh, '>:utf8', "$pub_dir/atom.xml"
        or die "Cannot write atom.xml: $!";
    print $fh $output;
    close $fh;
    return 1;
}

sub publish_json_feed {
    my ( $config, $tt, $posts ) = @_;

    $posts //= [];
    my @sorted = sort { $b->{ date } cmp $a->{ date } } @$posts;
    my $max    = $config->{ show_max_posts } || 10;
    my @shown  = @sorted > $max ? @sorted[ 0 .. $max - 1 ] : @sorted;

    require JSON;

    my @items;
    for my $post ( @shown ) {
        push @items,
            {
            id             => $post->{ uri },
            url            => $post->{ uri },
            title          => $post->{ title },
            content_html   => $post->{ body_html },
            date_published => $post->{ date },
            };
    }

    my $feed = JSON::encode_json(
        {   version       => 'https://jsonfeed.org/version/1',
            title         => $config->{ title },
            home_page_url => $config->{ base_uri },
            feed_url      => $config->{ base_uri } . '/feed.json',
            items         => \@items,
        }
    );

    my $pub_dir =
           $config->{ publication_path }
        || $config->{ publication_directory }
        || '.';
    open my $fh, '>', "$pub_dir/feed.json"
        or die "Cannot write feed.json: $!";
    print $fh $feed;
    close $fh;
    return 1;
}

sub publish_notes_roll {
    my ( $config, $tt, $notes ) = @_;

    $notes //= [];
    my @sorted = sort { $b->{ date } <=> $a->{ date } } @$notes;

    my $output;
    my $stash = _build_template_stash( $config );
    $tt->process(
        'notes_roll.tt',
        {   %$stash,
            notes         => \@sorted,
            config        => $config,
            activeSection => 'notes_roll'
        },
        \$output
    ) or die $tt->error();

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    open my $fh, '>:utf8', "$pub_dir/notes_roll.html"
        or die "Cannot write notes_roll.html: $!";
    print $fh $output;
    close $fh;
    return 1;
}

sub publish_notes_json {
    my ( $config, $tt, $notes ) = @_;

    $notes //= [];
    my @sorted = sort { $b->{ date } <=> $a->{ date } } @$notes;
    my $max    = $config->{ show_max_posts } || 20;
    my @shown  = @sorted > $max ? @sorted[ 0 .. $max - 1 ] : @sorted;

    require JSON;

    my @items;
    for my $note ( @shown ) {
        my $title = $note->{ title }
            || _note_fallback_title( $note );
        push @items,
            {
            id             => $note->{ uri },
            url            => $note->{ uri },
            title          => $title,
            content_html   => $note->{ body_html },
            date_published => $note->{ date },
            };
    }

    my $base_uri = $config->{ base_uri } || 'http://localhost/';
    $base_uri =~ s{/$}{};
    my $feed = JSON::encode_json(
        {   version       => 'https://jsonfeed.org/version/1',
            title         => $config->{ title } || 'Notes',
            home_page_url => $base_uri,
            feed_url      => $base_uri . '/recent_notes.json',
            items         => \@items,
        }
    );

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    open my $fh, '>', "$pub_dir/recent_notes.json"
        or die "Cannot write recent_notes.json: $!";
    print $fh $feed;
    close $fh;
    return 1;
}

sub publish_site_css {
    my ( $config, $tt ) = @_;

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    my $css_dir = "$pub_dir/css";
    mkdir $css_dir unless -d $css_dir;

    my $output;
    $tt->process( 'site_css.tt', { config => $config }, \$output )
        or die $tt->error();

    open my $fh, '>:utf8', "$css_dir/site.css"
        or die "Cannot write site.css: $!";
    print $fh $output;
    close $fh;
    return 1;
}

sub publish_site_js {
    my ( $config, $tt ) = @_;

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    my $js_dir = "$pub_dir/js";
    mkdir $js_dir unless -d $js_dir;

    my $stash = _build_template_stash( $config );
    my $output;
    $tt->process( 'site_js.tt', { %$stash, config => $config }, \$output )
        or die $tt->error();

    open my $fh, '>:utf8', "$js_dir/site.js"
        or die "Cannot write site.js: $!";
    print $fh $output;
    close $fh;
    return 1;
}

sub incremental_publish_posts {
    my ( $config, $tt, $source_dir, $force, $verbose, $dryrun ) = @_;

    opendir my $dh, $source_dir or die "Cannot read $source_dir: $!";
    my @files =
        grep { /\.(?:md|markdown)$/i && -f "$source_dir/$_" } readdir( $dh );
    closedir $dh;

    require Burbleboy::Model::Post;
    my @published;
    for my $file ( @files ) {
        next if $file =~ /^\./;
        if ( $file =~ /[[:cntrl:]]/ ) {
            warn
                "Skipping $file (corrupt filename: contains control characters)\n";
            next;
        }
        my $source_file = "$source_dir/$file";

        my $post = eval {
            Burbleboy::Model::Post::parse_post( $source_file, $config );
        };
        if ( $@ ) { warn "Skipping $file: $@" if $verbose; next; }

        next
            unless $force
            || needs_update( $source_file, $post->{ publication_file } );

        if ( $dryrun ) {
            say "(dryrun) Would publish: $file";
            push @published, $post;
            next;
        }

        my $result = eval { publish_post( $source_file, $config, $tt ) };
        if ( $@ ) { warn "Error publishing $file: $@" if $verbose; next; }

        push @published, $result;
        say "Published: $file" if $verbose;
    }

    return \@published;
}

sub incremental_publish_notes {
    my ( $config, $tt, $notes_dir, $force, $verbose, $dryrun ) = @_;

    return [] unless -d $notes_dir;

    opendir my $dh, $notes_dir or die "Cannot read $notes_dir: $!";
    my @files =
        grep { /\.(?:txt|md|markdown)$/i && -f "$notes_dir/$_" }
        readdir( $dh );
    closedir $dh;

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';

    require Burbleboy::Model::Note;
    my @published;
    for my $file ( @files ) {
        next if $file =~ /^\./;
        if ( $file =~ /[[:cntrl:]]/ ) {
            warn
                "Skipping $file (corrupt filename: contains control characters)\n";
            next;
        }
        my $source_file = "$notes_dir/$file";

        my $note = eval {
            Burbleboy::Model::Note::parse_note( $source_file, $config );
        };
        if ( $@ ) { warn "Skipping note $file: $@" if $verbose; next; }

        my $pub_file = $note->{ publication_file };
        next unless $force || needs_update( $source_file, $pub_file );

        if ( $dryrun ) {
            say "(dryrun) Would publish note: $file";
            push @published, $note;
            next;
        }

        my $result = eval { publish_note( $source_file, $config, $tt ) };
        if ( $@ ) {
            warn "Error publishing note $file: $@" if $verbose;
            next;
        }

        push @published, $result;
        say "Published note: $file" if $verbose;
    }

    return \@published;
}

sub _slurp {
    my ( $file ) = @_;
    open my $fh, '<:encoding(UTF-8)', $file or return;
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub extract_body_from_html {
    my ( $html_file ) = @_;
    my $html = _slurp( $html_file ) or return undef;

    if ( $html =~ m{<!-- POST_BODY_START -->(.*?)<!-- POST_BODY_END -->}s ) {
        return $1;
    }

    if ( $html =~ m{<div class="body e-content">(.*?)</div>}s ) {
        return $1;
    }

    if ( $html =~ m{<div class="e-content">(.*?)</div>}s ) {
        return $1;
    }

    return undef;
}

sub fill_body_for_posts {
    my ( $posts, $pub_dir ) = @_;
    for my $post ( @$posts ) {
        next if $post->{ body_html } && length( $post->{ body_html } );
        my $html_file = "$pub_dir/$post->{published_filename}";
        my $body      = extract_body_from_html( $html_file );
        if ( defined $body ) {
            $post->{ body_html } = $body;
            $post->{ body }      = $body;
        }
    }
    return $posts;
}

sub fill_body_for_top_n {
    my ( $posts, $pub_dir, $n ) = @_;
    $n //= scalar @$posts;
    my $count = 0;
    for my $post ( @$posts ) {
        last if $count >= $n;
        next if $post->{ body_html } && length( $post->{ body_html } );
        my $html_file = "$pub_dir/$post->{published_filename}";
        my $body      = extract_body_from_html( $html_file );
        if ( defined $body ) {
            $post->{ body_html } = $body;
            $post->{ body }      = $body;
        }
        $count++;
    }
    return $posts;
}

sub _expand_tags {
    my ( $tags, $base_uri ) = @_;
    $base_uri ||= 'http://localhost/';
    $base_uri =~ s{/$}{};
    return [
        map {
            my $tag = $_;
            {   name            => $tag,
                normalized_name => lc( $tag ),
                uri => $base_uri . '/tags.html#tag-' . lc( $tag ) . '-list'
            }
        } @{ $tags // [] }
    ];
}

sub _meta_filepath {
    my ( $pub_filename, $pub_dir ) = @_;
    return "$pub_dir/_burbleboy/$pub_filename.meta.json";
}

sub read_all_meta {
    my ( $config, $type ) = @_;

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    my $meta_dir = "$pub_dir/_burbleboy";
    return [] unless -d $meta_dir;

    require File::Find;
    my @files;
    File::Find::find(
        sub {
            return unless /\.meta\.json$/ && -f $_;
            push @files, $File::Find::name;
        },
        $meta_dir
    );

    require JSON;
    my $base_uri = $config->{ base_uri } || 'http://localhost/';

    my @results;
    for my $file ( @files ) {
        my $meta = eval { JSON::decode_json( _slurp( $file ) ) };
        if ( $@ || !$meta ) {
            warn "Skipping corrupt meta file: $file\n";
            next;
        }
        next if $type && $meta->{ type } ne $type;

        my $html_file = "$pub_dir/$meta->{published_filename}";
        next unless -e $html_file;

        $meta->{ body }      = '';
        $meta->{ body_html } = '';

        if ( $meta->{ type } eq 'post' ) {
            require DateTime::Format::W3CDTF;
            my $parser = DateTime::Format::W3CDTF->new;
            my $dt     = $parser->parse_datetime( $meta->{ date } );
            $dt->set_time_zone( 'UTC' );
            $meta->{ utc_date }   = $dt;
            $meta->{ year }       = $dt->year;
            $meta->{ month }      = sprintf( '%02d', $dt->month );
            $meta->{ month_name } = $dt->month_name;
            $meta->{ day }        = sprintf( '%02d', $dt->day );
        } else {
            require DateTime;
            my $dt = DateTime->from_epoch(
                epoch     => $meta->{ date },
                time_zone => 'UTC'
            );
            $meta->{ utc_date }      = $dt;
            $meta->{ date_as_mysql } = $dt->strftime( '%Y-%m-%d %H:%M:%S' );
        }

        $meta->{ tags } = _expand_tags( $meta->{ tags }, $base_uri );

        push @results, $meta;
    }

    my $date_cmp = sub {
        my ( $x, $y ) = @_;
        return 0 unless defined $x && defined $y;
        return $x <=> $y if $x =~ /^\d+$/ && $y =~ /^\d+$/;
        return $x cmp $y;
    };
    @results = sort {
        $date_cmp->( $b->{ date }, $a->{ date } )
            || ( $a->{ title } || '' ) cmp( $b->{ title } || '' )
    } @results;

    return \@results;
}

sub write_meta {
    my ( $item, $config, $type ) = @_;

    my $pub_dir =
           $config->{ publication_directory }
        || $config->{ publication_path }
        || '.';
    my $meta_dir = "$pub_dir/_burbleboy";

    my $filename;
    if ( $type eq 'post' ) {
        $filename = $item->{ published_filename };
    } else {
        $filename = $item->{ published_filename }
            || basename( $item->{ publication_file } );
    }

    my $meta = { type => $type };
    if ( $type eq 'post' ) {
        $meta->{ title }              = $item->{ title };
        $meta->{ date }               = $item->{ date };
        $meta->{ uri }                = $item->{ uri };
        $meta->{ tags }               = $item->{ tags };
        $meta->{ reading_time }       = $item->{ reading_time };
        $meta->{ id }                 = $item->{ id };
        $meta->{ description }        = $item->{ description };
        $meta->{ published_filename } = $filename;
        $meta->{ source_file }        = $item->{ source_file };
    } else {
        $meta->{ date }               = $item->{ date };
        $meta->{ uri }                = $item->{ uri };
        $meta->{ tags }               = $item->{ tags };
        $meta->{ id }                 = $item->{ id };
        $meta->{ published_filename } = $filename;
        $meta->{ source_file }        = $item->{ source_file };
    }

    require JSON;
    my $json = JSON::encode_json( $meta );

    my $tmp   = "$meta_dir/$filename.meta.json.tmp";
    my $final = "$meta_dir/$filename.meta.json";
    File::Path::mkpath( File::Basename::dirname( $tmp ) );
    open my $fh, '>', $tmp or die "Cannot write $tmp: $!";
    print $fh $json;
    close $fh;
    rename( $tmp, $final ) or die "Cannot rename $tmp to $final: $!";

    return 1;
}

sub try_publish {
    my ( $label, $sub, $verbose ) = @_;

    my $result = eval { $sub->() };
    if ( $@ ) {
        warn "Error $label: $@" if $verbose;
        return;
    }

    return $result;
}

1;
