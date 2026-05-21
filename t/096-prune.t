use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Spec;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(
    publish_note publish_post prune_orphans regenerate_aggregates
    publish_front_page publish_archive_page publish_tags_index
    publish_notes_roll read_all_meta fill_body_for_posts
);

Main();
exit;

sub _write_minimal_templates {
    my ( $dir ) = @_;

    open my $fh, '>', "$dir/layout.tt" or die "Cannot write layout.tt: $!";
    print $fh <<'EOF';
<!DOCTYPE html>
<html>
<head><title>[% config.title %]</title></head>
<body>[% content %]</body>
</html>
EOF
    close $fh;

    open $fh, '>', "$dir/note.tt" or die "Cannot write note.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<div class="note"><!-- POST_BODY_START --><div class="e-content">[% note.body %]</div><!-- POST_BODY_END --></div>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/single_post.tt"
        or die "Cannot write single_post.tt: $!";
    print $fh <<'EOF';
[% WRAPPER layout.tt %]
<article>
<h1>[% post.title %]</h1>
<!-- POST_BODY_START -->
<div class="body e-content">[% post.body %]</div>
<!-- POST_BODY_END -->
</article>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/front_page.tt"
        or die "Cannot write front_page.tt: $!";
    print $fh <<'EOF';
[% WRAPPER layout.tt %]
[% FOREACH p = posts %]
<div class="post">[% p.title %]</div>
<div class="body">[% p.body %]</div>
[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/archive.tt" or die "Cannot write archive.tt: $!";
    print $fh <<'EOF';
[% WRAPPER layout.tt %]
[% FOREACH p = posts %]
<div class="archive-entry">[% p.year %]/[% p.month %] - [% p.title %]</div>
[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/tags.tt" or die "Cannot write tags.tt: $!";
    print $fh <<'EOF';
[% WRAPPER layout.tt %]
[% FOREACH letter = ['A'..'Z'] %]
[% IF tag_links.$letter %]
[% FOREACH tag = tag_links.$letter.keys.sort %]
[% FOREACH link = tag_links.$letter.$tag %]
<a href="[% link.uri %]" class="tag-link">[% link.title %]</a>
[% END %]
[% END %]
[% END %]
[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/notes_roll.tt"
        or die "Cannot write notes_roll.tt: $!";
    print $fh <<'EOF';
[% WRAPPER layout.tt %]
[% FOREACH note = notes %]
<div class="note">[% note.body %]</div>
[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/feed.tt" or die "Cannot write feed.tt: $!";
    print $fh <<'EOF';
<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom">
[% FOR post IN posts %]
<entry><title>[% post.title %]</title></entry>
[% END %]
</feed>
EOF
    close $fh;
}

sub test_prune_basic {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path }      = $site->{ publication_dir };
    $config->{ publication_directory } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/prune-test-note.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "This note will be pruned.\n";
    close $fh;

    my $note = publish_note( $source, $config, $tt );

    my $pub_file = $note->{ publication_file };
    my $meta_file =
          "$site->{ publication_dir }/_burbleboy/"
        . $note->{ published_filename }
        . ".meta.json";

    ok( -e $pub_file,  'published note file exists before prune' );
    ok( -e $meta_file, 'meta file exists before prune' );

    unlink $source or die "Cannot remove source: $!";

    my $count = prune_orphans( $config, 0, 0 );

    is( $count, 1, 'prune_orphans returns 1 for one orphan' );
    ok( !-e $pub_file,  'published note file removed after prune' );
    ok( !-e $meta_file, 'meta file removed after prune' );

    teardown_test_site( $site );
}

sub test_prune_preserves_existing {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path }      = $site->{ publication_dir };
    $config->{ publication_directory } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/keep-note.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "This note should stay.\n";
    close $fh;

    my $note = publish_note( $source, $config, $tt );

    my $pub_file = $note->{ publication_file };
    my $meta_file =
          "$site->{ publication_dir }/_burbleboy/"
        . $note->{ published_filename }
        . ".meta.json";

    ok( -e $pub_file,  'published note file exists before prune' );
    ok( -e $meta_file, 'meta file exists before prune' );

    my $count = prune_orphans( $config, 0, 0 );

    is( $count, 0, 'prune_orphans returns 0 when source still exists' );
    ok( -e $pub_file,  'published note file survives prune' );
    ok( -e $meta_file, 'meta file survives prune' );

    teardown_test_site( $site );
}

sub test_prune_dryrun {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path }      = $site->{ publication_dir };
    $config->{ publication_directory } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/dryrun-note.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "This note should survive dryrun.\n";
    close $fh;

    my $note = publish_note( $source, $config, $tt );

    my $pub_file = $note->{ publication_file };
    my $meta_file =
          "$site->{ publication_dir }/_burbleboy/"
        . $note->{ published_filename }
        . ".meta.json";

    unlink $source or die "Cannot remove source: $!";

    my $count = prune_orphans( $config, 0, 1 );

    is( $count, 1, 'prune_orphans reports 1 orphan even in dryrun' );
    ok( -e $pub_file,  'published file not removed in dryrun' );
    ok( -e $meta_file, 'meta file not removed in dryrun' );

    teardown_test_site( $site );
}

sub test_prune_posts {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path }      = $site->{ publication_dir };
    $config->{ publication_directory } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-test-post.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Test Post\n\nBody of test post.\n";
    close $fh;

    my $post     = publish_post( $source, $config, $tt );
    my $pub_file = $post->{ publication_file };

    ok( -e $pub_file, 'published post file exists before prune' );

    unlink $source or die "Cannot remove source: $!";

    state $meta_dir = "$site->{ publication_dir }/_burbleboy";
    my $meta_count_before = 0;
    opendir my $dh, $meta_dir or die "Cannot open $meta_dir: $!";
    while ( my $f = readdir( $dh ) ) {
        $meta_count_before++ if $f =~ /\.meta\.json$/;
    }
    closedir $dh;

    my $count = prune_orphans( $config, 0, 0 );

    is( $count, 1, 'prune_orphans returns 1 for orphaned post' );
    ok( !-e $pub_file, 'published post file removed after prune' );

    my $meta_count_after = 0;
    opendir $dh, $meta_dir or die "Cannot open $meta_dir: $!";
    while ( my $f = readdir( $dh ) ) {
        $meta_count_after++ if $f =~ /\.meta\.json$/;
    }
    closedir $dh;

    is( $meta_count_after,
        $meta_count_before - 1,
        'one fewer meta file after prune'
    );

    teardown_test_site( $site );
}

sub test_prune_nothing_to_do {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path }      = $site->{ publication_dir };
    $config->{ publication_directory } = $site->{ publication_dir };

    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    mkdir $meta_dir or die "Cannot create $meta_dir: $!";

    my $count = prune_orphans( $config, 0, 0 );

    is( $count, 0, 'prune_orphans returns 0 on empty _burbleboy dir' );

    teardown_test_site( $site );
}

sub test_prune_aggregates_post {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path }      = $site->{ publication_dir };
    $config->{ publication_directory } = $site->{ publication_dir };
    $config->{ author_name }           = 'Test Author';

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-prune-post.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Prune Post\ntags: test\n\nBody of prune post.\n";
    close $fh;

    publish_post( $source, $config, $tt );
    my $all_posts = read_all_meta( $config, 'post' );
    publish_front_page( $config, $tt, $all_posts );
    publish_archive_page( $config, $tt, $all_posts );
    publish_tags_index( $config, $tt, $all_posts );

    open $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $front = do { local $/; <$fh> };
    close $fh;
    like $front, qr/Prune Post/, 'front page shows post before prune';

    open $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    my $archive = do { local $/; <$fh> };
    close $fh;
    like $archive, qr/Prune Post/, 'archive shows post before prune';

    open $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $tags = do { local $/; <$fh> };
    close $fh;
    like $tags, qr/Prune Post/, 'tags page shows post before prune';

    unlink $source or die "Cannot remove source: $!";
    my $pruned = prune_orphans( $config, 0, 0 );
    is( $pruned, 1, 'pruned 1 orphan' );

    regenerate_aggregates( $config, $tt );

    open $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    $front = do { local $/; <$fh> };
    close $fh;
    unlike $front, qr/Prune Post/, 'front page no longer shows pruned post';

    open $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    $archive = do { local $/; <$fh> };
    close $fh;
    unlike $archive, qr/Prune Post/, 'archive no longer shows pruned post';

    open $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    $tags = do { local $/; <$fh> };
    close $fh;
    unlike $tags, qr/Prune Post/, 'tags no longer shows pruned post';

    teardown_test_site( $site );
}

sub test_prune_aggregates_note {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path }      = $site->{ publication_dir };
    $config->{ publication_directory } = $site->{ publication_dir };
    $config->{ author_name }           = 'Test Author';

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/prune-test-note-agg.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "Prune this note from roll.\n";
    close $fh;

    publish_note( $source, $config, $tt );
    my $all_notes = read_all_meta( $config, 'note' );
    fill_body_for_posts( $all_notes, $site->{ publication_dir } );
    publish_notes_roll( $config, $tt, $all_notes );

    open $fh, '<', "$site->{ publication_dir }/notes_roll.html" or die;
    my $roll = do { local $/; <$fh> };
    close $fh;
    like $roll, qr/Prune this note/, 'notes roll shows note before prune';

    unlink $source or die "Cannot remove source: $!";
    my $pruned = prune_orphans( $config, 0, 0 );
    is( $pruned, 1, 'pruned 1 orphan note' );

    regenerate_aggregates( $config, $tt );

    open $fh, '<', "$site->{ publication_dir }/notes_roll.html" or die;
    $roll = do { local $/; <$fh> };
    close $fh;
    unlike $roll, qr/Prune this note/,
        'notes roll no longer shows pruned note';

    teardown_test_site( $site );
}

sub Main {
    test_prune_basic();
    test_prune_preserves_existing();
    test_prune_dryrun();
    test_prune_posts();
    test_prune_nothing_to_do();
    test_prune_aggregates_post();
    test_prune_aggregates_note();
    done_testing();
}
