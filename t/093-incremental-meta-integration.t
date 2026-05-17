use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use Cwd qw(cwd);
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(
    incremental_publish_posts incremental_publish_notes
    publish_front_page publish_archive_page publish_tags_index
    publish_atom_feed publish_json_feed
    publish_notes_roll publish_notes_json
    read_all_meta fill_body_for_posts fill_body_for_top_n
);

Main();
exit;

sub _write_templates {
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
[% IF posts.size > 0 %]
[% FOREACH p = posts %]
<div class="post">[% p.title %] - [% p.date %]</div>
<div class="body">[% p.body %]</div>
[% END %]
[% ELSE %]
<p class="no-posts">No posts</p>
[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/archive.tt" or die "Cannot write archive.tt: $!";
    print $fh <<'EOF';
[% WRAPPER layout.tt %]
[% IF posts.size > 0 %]
[% FOREACH p = posts %]
<div class="archive-entry">[% p.year %]/[% p.month %] - [% p.title %]</div>
[% END %]
[% ELSE %]
<p class="no-posts">No archive posts</p>
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
<div class="tag-group" data-letter="[% letter %]" data-tag="[% tag %]" data-count="[% tag_links.$letter.$tag.size %]">
[% FOREACH link = tag_links.$letter.$tag %]
<a href="[% link.uri %]" class="tag-link">[% link.title %]</a>
[% END %]
</div>
[% END %]
[% END %]
[% END %]
[% IF tag_links.size == 0 %]<p class="no-tags">No tags</p>[% END %]
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/feed.tt" or die "Cannot write feed.tt: $!";
    print $fh <<'EOF';
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>[% config.title %]</title>
  <link href="[% config.base_uri %]/atom.xml" rel="self" />
  <link href="[% config.base_uri %]" />
  <updated>[% timestamp %]</updated>
  <id>[% config.base_uri %]</id>
  <author>
    <name>[% config.author_name %]</name>
  </author>
[% FOR post IN posts %]
  <entry>
    <title>[% post.title %]</title>
    <link href="[% post.uri %]"/>
    <published>[% post.published_timestamp %]</published>
    <updated>[% post.updated_timestamp %]</updated>
    <id>[% post.uri %]</id>
    <content type="html">[% post.body %]</content>
  </entry>
[% END %]
</feed>
EOF
    close $fh;

    open $fh, '>', "$dir/note.tt" or die "Cannot write note.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' section_title = "Note" %]
<div class="note">
<!-- POST_BODY_START -->
<div class="e-content">[% note.body_html %]</div>
<!-- POST_BODY_END -->
</div>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/notes_roll.tt"
        or die "Cannot write notes_roll.tt: $!";
    print $fh <<'END_TMPL';
[% IF notes.size > 0 -%]
  [% FOREACH note = notes %]
    <div class="note">
      <div class="body">[% note.body_html %]</div>
      <div class="uri"><a href="[% note.uri %]">permalink</a></div>
    </div>
  [% END %]
[% ELSE %]
  <em>No notes posted yet.</em>
[% END %]
END_TMPL
    close $fh;
}

sub test_integ_fresh_site {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-fresh.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Fresh Post\n\nHello world.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $all = read_all_meta( $config, 'post' );
    ok( defined $all, 'read_all_meta returns defined for fresh site' );
    is( scalar @$all,         1,            'fresh site: 1 post returned' );
    is( $all->[ 0 ]{ title }, 'Fresh Post', 'fresh site: title matches' );

    teardown_test_site( $site );
}

sub test_integ_incremental_append {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source_a = "$site->{ source_dir }/2024y06m15d_12h00m00s-post-a.md";
    open my $fh, '>', $source_a or die "Cannot write $source_a: $!";
    print $fh "title: Post A\n\nBody A.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $source_b = "$site->{ source_dir }/2024y07m20d_10h00m00s-post-b.md";
    open $fh, '>', $source_b or die "Cannot write $source_b: $!";
    print $fh "title: Post B\n\nBody B.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $all = read_all_meta( $config, 'post' );
    is( scalar @$all, 2, 'incremental append: 2 posts returned' );
    is( $all->[ 0 ]{ title },
        'Post B', 'incremental append: newest first (Post B)' );
    is( $all->[ 1 ]{ title },
        'Post A', 'incremental append: older second (Post A)' );

    teardown_test_site( $site );
}

sub test_integ_republish {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-repub.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: First version\n\nOriginal body.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    sleep 1;

    open $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Second version\n\nUpdated body.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $all = read_all_meta( $config, 'post' );
    is( scalar @$all, 1, 'republish: single meta entry (no duplicate)' );
    is( $all->[ 0 ]{ title },
        'Second version',
        'republish: title reflects update'
    );

    fill_body_for_posts( $all, $site->{ publication_dir } );
    like(
        $all->[ 0 ]{ body },
        qr/Updated body/,
        'republish: body shows updated content'
    );

    teardown_test_site( $site );
}

sub test_integ_full_rebuild {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    for my $i ( 1 .. 3 ) {
        my $day = sprintf( "%02d", $i );
        my $source =
            "$site->{ source_dir }/2024y06${day}d_12h00m00s-post-$i.md";
        open my $fh, '>', $source or die "Cannot write $source: $!";
        print $fh "title: Post $i\n\nBody $i.\n";
        close $fh;
    }

    incremental_publish_posts( $config, $tt, $site->{ source_dir }, 1 );

    my $all = read_all_meta( $config, 'post' );
    is( scalar @$all, 3, 'full rebuild: all 3 posts returned' );

    teardown_test_site( $site );
}

sub test_integ_front_page_body {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ show_max_posts }   = 5;
    $config->{ author_name }      = 'Test Author';

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $body =
        "<p>First paragraph.</p>\n<div class=\"special\">Nested content.</div>\n<p>Third paragraph.</p>";
    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-body.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Body Post\n\n$body\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $all = read_all_meta( $config, 'post' );
    fill_body_for_top_n( $all, $site->{ publication_dir }, 5 );
    publish_front_page( $config, $tt, $all );

    open $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/First paragraph/,
        'front page body: first paragraph present';
    like $content, qr/Nested content/,
        'front page body: nested <div> content not truncated';
    like $content, qr/Third paragraph/,
        'front page body: third paragraph present';

    teardown_test_site( $site );
}

sub test_integ_archive_metadata_only {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-arch.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Archive Post\n\nBody content.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $all = read_all_meta( $config, 'post' );
    publish_archive_page( $config, $tt, $all );

    open $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content,   qr/Archive Post/, 'archive metadata: title appears';
    like $content,   qr{2024/06},      'archive metadata: year/month appears';
    unlike $content, qr/Body content/, 'archive metadata: body HTML absent';

    teardown_test_site( $site );
}

sub test_integ_feed_body_all {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ author_name }      = 'Test Author';

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    for my $i ( 1 .. 3 ) {
        my $day = sprintf( "%02d", $i );
        my $source =
            "$site->{ source_dir }/2024y06${day}d_12h00m00s-feed-$i.md";
        open my $fh, '>', $source or die "Cannot write $source: $!";
        print $fh "title: Feed Post $i\n\nBody content for post $i.\n";
        close $fh;
    }

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $all = read_all_meta( $config, 'post' );
    fill_body_for_posts( $all, $site->{ publication_dir } );
    publish_atom_feed( $config, $tt, $all );

    open my $fh, '<', "$site->{ publication_dir }/atom.xml" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr{<content type="html">},
        'feed body: content element present';
    like $content, qr/Body content for post 1/,
        'feed body: post 1 body present';
    like $content, qr/Body content for post 2/,
        'feed body: post 2 body present';
    like $content, qr/Body content for post 3/,
        'feed body: post 3 body present';

    my @entries = $content =~ /<entry>/g;
    is( scalar @entries, 3, 'feed body: 3 entries in atom feed' );

    teardown_test_site( $site );
}

sub test_integ_notes_incremental {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $notes_dir = "$site->{ source_dir }/notes";
    mkdir $notes_dir or die "Cannot create $notes_dir: $!";

    my $note_source = "$notes_dir/my-note.md";
    open my $fh, '>', $note_source or die "Cannot write $note_source: $!";
    print $fh "Hello from an incremental note.\n";
    close $fh;

    my $orig_cwd = cwd();
    chdir $site->{ publication_dir }
        or die "Cannot chdir to $site->{ publication_dir }: $!";
    incremental_publish_notes( $config, $tt, $notes_dir );
    chdir $orig_cwd;

    my $all = read_all_meta( $config, 'note' );
    ok( defined $all,
        'notes incremental: read_all_meta for notes returns defined' );
    is( scalar @$all, 1, 'notes incremental: 1 note returned' );

    fill_body_for_posts( $all, $site->{ publication_dir } );
    like(
        $all->[ 0 ]{ body },
        qr/Hello from an incremental note/,
        'notes incremental: note body extractable from published HTML'
    );

    teardown_test_site( $site );
}

sub Main {
    test_integ_fresh_site();
    test_integ_incremental_append();
    test_integ_republish();
    test_integ_full_rebuild();
    test_integ_front_page_body();
    test_integ_archive_metadata_only();
    test_integ_feed_body_all();
    test_integ_notes_incremental();
    done_testing();
}
