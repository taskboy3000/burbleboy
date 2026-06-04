use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish
    qw(_publish_posts _publish_notes publish_post publish_note run_publish needs_update);

Main();
exit;

sub Main {
    test_publish_all_posts_skip_unchanged();
    test_publish_all_posts_publish_new();
    test_publish_all_posts_publish_newer();
    test_publish_all_meta_not_rewritten();
    test_publish_all_aggregates_always_regenerated();
    test_publish_all_force_republishes();
    test_publish_all_notes_skip_unchanged();
    test_publish_all_posts_dryrun();
    done_testing();
}

sub _write_minimal_templates {
    my ( $dir ) = @_;

    open my $fh, '>', "$dir/layout.tt" or die "Cannot write layout.tt: $!";
    print $fh <<'EOF';
<!DOCTYPE html>
<html lang="en">
<head><title>[% config.site_name %]</title></head>
<body>[% content %]</body>
</html>
EOF
    close $fh;

    open $fh, '>', "$dir/single_post.tt"
        or die "Cannot write single_post.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<article><h1>[% post.title %]</h1><div>[% post.body %]</div></article>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/note.tt" or die "Cannot write note.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<div>[% note.body %]</div>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/front_page.tt"
        or die "Cannot write front_page.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<h1>Front Page</h1>
[% FOREACH post IN posts %]
<article><h2>[% post.title %]</h2>[% post.body %]</article>
[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/archive.tt" or die "Cannot write archive.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<h1>Archive</h1>
[% FOREACH post IN posts %]
<article><h2>[% post.title %]</h2></article>
[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/feed.tt" or die "Cannot write feed.tt: $!";
    print $fh <<'EOF';
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
<title>[% config.site_name %]</title>
[% FOREACH post IN posts %]
<entry><title>[% post.title %]</title></entry>
[% END %]
</feed>
EOF
    close $fh;

    open $fh, '>', "$dir/feed.json.tt"
        or die "Cannot write feed.json.tt: $!";
    print $fh <<'EOF';
{"items": [[% FOREACH post IN posts %]{"title":"[% post.title %]"}[% UNLESS loop.last %],[% END %][% END %]]}
EOF
    close $fh;

    open $fh, '>', "$dir/notes_roll.tt"
        or die "Cannot write notes_roll.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<h1>Notes</h1>
[% FOREACH note IN notes %]
<div>[% note.body %]</div>
[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/recent_notes.json.tt"
        or die "Cannot write recent_notes.json.tt: $!";
    print $fh <<'EOF';
{"notes": []}
EOF
    close $fh;

    open $fh, '>', "$dir/tags.tt" or die "Cannot write tags.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<h1>Tags</h1>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/site_css.tt"
        or die "Cannot write site_css.tt: $!";
    print $fh "/* site css */\n";
    close $fh;

    open $fh, '>', "$dir/site_js.tt"
        or die "Cannot write site_js.tt: $!";
    print $fh "// site js\n";
    close $fh;
}

sub test_publish_all_posts_skip_unchanged {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ site_name }        = 'Test';
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-skip.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Skip Post\n\nBody.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    my $html_file =
        "$site->{ publication_dir }/2024y01m15d_12h00m00s-skip.html";
    ok( -e $html_file, 'HTML file exists after first publish' );

    utime( time - 200, time - 200, $source );

    my $result = _publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result,
        0, '_publish_posts skips file when source older than output' );

    teardown_test_site( $site );
}

sub test_publish_all_posts_publish_new {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ site_name }        = 'Test';
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y02m10d_08h30m00s-new.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: New Post\n\nContent.\n";
    close $fh;

    my $result = _publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result,         1,          'new file: one post published' );
    is( $result->[ 0 ]{ title }, 'New Post', 'new file: correct title' );

    ok( -e $result->[ 0 ]{ publication_file },
        'new file: output file exists'
    );

    teardown_test_site( $site );
}

sub test_publish_all_posts_publish_newer {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ site_name }        = 'Test';
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y03m20d_14h15m00s-upd.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Updated\n\nOld content.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    sleep 1;

    open $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Updated\n\nNew content.\n";
    close $fh;

    my $result = _publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result, 1, 'source newer: post republished' );

    teardown_test_site( $site );
}

sub test_publish_all_meta_not_rewritten {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ site_name }        = 'Test';
    $config->{ source_directory } = $site->{ source_dir };
    $config->{ base_uri }         = 'http://example.com';
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y04m05d_09h00m00s-meta.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Meta Post\n\nBody content.\n";
    close $fh;

    run_publish( $config, $tt, { publish_all => 1 } );

    my $meta_file =
        "$site->{ publication_dir }/_burbleboy/2024y04m05d_09h00m00s-meta.html.meta.json";
    ok( -e $meta_file, 'meta file created after first publish-all' );

    my $html_file =
        "$site->{ publication_dir }/2024y04m05d_09h00m00s-meta.html";
    ok( -e $html_file, 'HTML file created after first publish-all' );

    my @meta_stat_before = stat( $meta_file );
    my @html_stat_before = stat( $html_file );

    sleep 1;

    my $meta_mtime_before = $meta_stat_before[ 9 ];
    run_publish( $config, $tt, { publish_all => 1 } );

    ok( -e $meta_file, 'meta file still exists after second publish-all' );

    my @meta_stat_after  = stat( $meta_file );
    my $meta_mtime_after = $meta_stat_after[ 9 ];

    is( $meta_mtime_after, $meta_mtime_before,
        'meta file mtime unchanged when no source changed' );

    my @html_stat_after  = stat( $html_file );
    my $html_mtime_after = $html_stat_after[ 9 ];

    is( $html_mtime_after,
        $html_stat_before[ 9 ],
        'HTML file mtime unchanged when no source changed'
    );

    teardown_test_site( $site );
}

sub test_publish_all_aggregates_always_regenerated {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ site_name }        = 'Test';
    $config->{ source_directory } = $site->{ source_dir };
    $config->{ base_uri }         = 'http://example.com';
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y05m10d_11h00m00s-agg.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Agg Post\n\nBody.\n";
    close $fh;

    run_publish( $config, $tt, { publish_all => 1 } );

    my $front_page = "$site->{ publication_dir }/blog.html";
    ok( -e $front_page, 'blog.html exists after first publish' );

    my @before_stat = stat( $front_page );

    utime( time - 300, time - 300, $source );

    sleep 1;

    run_publish( $config, $tt, { publish_all => 1 } );

    ok( -e $front_page, 'blog.html exists after second publish-all' );

    my @after_stat = stat( $front_page );

    ok( $after_stat[ 9 ] > $before_stat[ 9 ],
        'blog.html regenerated even when no posts changed' );

    ok( -e "$site->{ publication_dir }/archive.html",
        'archive.html still exists' );
    ok( -e "$site->{ publication_dir }/atom.xml",  'atom.xml still exists' );
    ok( -e "$site->{ publication_dir }/feed.json", 'feed.json still exists' );

    teardown_test_site( $site );
}

sub test_publish_all_force_republishes {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ site_name }        = 'Test';
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y06m01d_10h00m00s-force.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Force Post\n\nBody.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    my $html_file =
        "$site->{ publication_dir }/2024y06m01d_10h00m00s-force.html";
    ok( -e $html_file, 'HTML file exists before force publish' );

    utime( time - 300, time - 300, $source );

    my $result = _publish_posts( $config, $tt, $site->{ source_dir },
        undef, undef, 1 );
    is( scalar @$result, 1, 'force: publishes even with older source' );

    teardown_test_site( $site );
}

sub test_publish_all_notes_skip_unchanged {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ site_name }        = 'Test';
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $notes_dir = "$site->{ source_dir }/notes";
    mkdir $notes_dir or die "Cannot create $notes_dir: $!";

    my $source = "$notes_dir/2024y01m15d_12h00m00s-skip-note.txt";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "Note body.\n";
    close $fh;

    publish_note( $source, $config, $tt );

    my $html_file =
        "$site->{ publication_dir }/notes/2024y01m15d_12h00m00s-skip-note.html";
    ok( -e $html_file, 'note HTML file exists after first publish' );

    utime( time - 200, time - 200, $source );

    my $result = _publish_notes( $config, $tt, $site->{ source_dir } );
    is( scalar @$result,
        0, '_publish_notes skips note when source older than output' );

    teardown_test_site( $site );
}

sub test_publish_all_posts_dryrun {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ site_name }        = 'Test';
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y07m01d_12h00m00s-dry.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Dry Run\n\nBody.\n";
    close $fh;

    my $result =
        _publish_posts( $config, $tt, $site->{ source_dir }, undef, 1 );

    is( scalar @$result, 1, 'dryrun: returns parsed posts' );

    my $html = "$site->{ publication_dir }/2024y07m01d_12h00m00s-dry.html";
    ok( !-e $html,  'dryrun: no file written' );
    ok( -e $source, 'dryrun: source file still present' );

    teardown_test_site( $site );
}
