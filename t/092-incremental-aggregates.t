use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use Cwd qw(cwd);
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(
    publish_post publish_note publish_front_page publish_archive_page
    publish_tags_index publish_atom_feed publish_json_feed
    publish_notes_roll publish_notes_json
    read_all_meta fill_body_for_posts fill_body_for_top_n
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

sub test_incremental_all_aggregates_full {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ author_name }      = 'Test Author';

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source_a = "$site->{ source_dir }/2024y06m15d_12h00m00s-post-a.md";
    open my $fh, '>', $source_a or die "Cannot write $source_a: $!";
    print $fh "title: Post A\ntags: perl\n\nBody of post A.\n";
    close $fh;

    publish_post( $source_a, $config, $tt );

    my $source_b = "$site->{ source_dir }/2024y01m15d_12h00m00s-post-b.md";
    open $fh, '>', $source_b or die "Cannot write $source_b: $!";
    print $fh "title: Post B\ntags: perl\n\nBody of post B.\n";
    close $fh;

    publish_post( $source_b, $config, $tt );

    my $all_posts = read_all_meta( $config, 'post' );
    ok( defined $all_posts, 'read_all_meta returns defined' );
    is( scalar @$all_posts, 2, 'read_all_meta returns both posts' );

    fill_body_for_top_n( $all_posts, $site->{ publication_dir }, 5 );
    fill_body_for_posts( $all_posts, $site->{ publication_dir } );

    publish_front_page( $config, $tt, $all_posts );
    publish_archive_page( $config, $tt, $all_posts );
    publish_tags_index( $config, $tt, $all_posts );
    publish_atom_feed( $config, $tt, $all_posts );
    publish_json_feed( $config, $tt, $all_posts );

    open $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $front_content = do { local $/; <$fh> };
    close $fh;

    like $front_content, qr/Post A/, 'front page shows Post A (newer)';
    like $front_content, qr/Post B/, 'front page shows Post B (older)';
    ok( index( $front_content, 'Post A' ) < index( $front_content, 'Post B' ),
        'newest post first on front page'
    );

    open $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    my $archive_content = do { local $/; <$fh> };
    close $fh;

    like $archive_content, qr/Post A/, 'archive shows Post A';
    like $archive_content, qr/Post B/, 'archive shows Post B';

    open $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $tags_content = do { local $/; <$fh> };
    close $fh;

    like $tags_content, qr/Post A/, 'tags page links to Post A';
    like $tags_content, qr/Post B/, 'tags page links to Post B';

    teardown_test_site( $site );
}

sub test_incremental_republish_aggregates {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

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

    publish_post( $source, $config, $tt );

    sleep 1;

    open $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Second version\n\nUpdated body.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    my $all_posts = read_all_meta( $config, 'post' );
    is( scalar @$all_posts, 1, 'republish results in single meta entry' );
    is( $all_posts->[ 0 ]{ title },
        'Second version',
        'title reflects second publish'
    );

    publish_archive_page( $config, $tt, $all_posts );

    open $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    my $archive_content = do { local $/; <$fh> };
    close $fh;

    like $archive_content, qr/Second version/, 'archive shows updated title';

    teardown_test_site( $site );
}

sub test_incremental_archive_no_body {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source_a = "$site->{ source_dir }/2024y06m15d_12h00m00s-alpha.md";
    open my $fh, '>', $source_a or die "Cannot write $source_a: $!";
    print $fh "title: Alpha\n\nAlpha body.\n";
    close $fh;
    publish_post( $source_a, $config, $tt );

    my $source_b = "$site->{ source_dir }/2024y01m15d_12h00m00s-beta.md";
    open $fh, '>', $source_b or die "Cannot write $source_b: $!";
    print $fh "title: Beta\n\nBeta body.\n";
    close $fh;
    publish_post( $source_b, $config, $tt );

    my $all_posts = read_all_meta( $config, 'post' );

    publish_archive_page( $config, $tt, $all_posts );

    open $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content,   qr/Alpha/,      'archive shows Alpha';
    like $content,   qr/Beta/,       'archive shows Beta';
    unlike $content, qr/Alpha body/, 'archive output has no body HTML';
    unlike $content, qr/Beta body/,  'archive output has no body HTML';

    teardown_test_site( $site );
}

sub test_incremental_front_page_body {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ show_max_posts }   = 5;
    $config->{ author_name }      = 'Test Author';

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-body.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Body Post\n\nFirst paragraph.\n\nSecond paragraph.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    my $all_posts = read_all_meta( $config, 'post' );
    fill_body_for_top_n( $all_posts, $site->{ publication_dir }, 5 );
    publish_front_page( $config, $tt, $all_posts );

    open $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/First paragraph/, 'front page contains body HTML';
    like $content, qr/Second paragraph/,
        'front page contains multi-paragraph body';

    teardown_test_site( $site );
}

sub test_incremental_atom_feed_body {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ author_name }      = 'Test Author';

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source_a = "$site->{ source_dir }/2024y06m15d_12h00m00s-feed-a.md";
    open my $fh, '>', $source_a or die "Cannot write $source_a: $!";
    print $fh "title: Feed A\n\nBody A content.\n";
    close $fh;
    publish_post( $source_a, $config, $tt );

    my $source_b = "$site->{ source_dir }/2024y01m15d_12h00m00s-feed-b.md";
    open $fh, '>', $source_b or die "Cannot write $source_b: $!";
    print $fh "title: Feed B\n\nBody B content.\n";
    close $fh;
    publish_post( $source_b, $config, $tt );

    my $all_posts = read_all_meta( $config, 'post' );
    fill_body_for_posts( $all_posts, $site->{ publication_dir } );
    publish_atom_feed( $config, $tt, $all_posts );

    open $fh, '<', "$site->{ publication_dir }/atom.xml" or die;
    my $atom_content = do { local $/; <$fh> };
    close $fh;

    like $atom_content, qr{<content type="html">},
        'atom feed has content element';
    like $atom_content, qr/Body A content/,
        'atom feed contains body for post A';
    like $atom_content, qr/Body B content/,
        'atom feed contains body for post B';

    teardown_test_site( $site );
}

sub test_incremental_notes_aggregates {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source_note = "$site->{ source_dir }/my-note.md";
    open my $fh, '>', $source_note or die "Cannot write $source_note: $!";
    print $fh "Hello from a test note.\n";
    close $fh;

    my $orig_cwd = cwd();
    chdir $site->{ publication_dir }
        or die "Cannot chdir to $site->{ publication_dir }: $!";
    my $note = publish_note( $source_note, $config, $tt );
    chdir $orig_cwd;

    my $all_notes = read_all_meta( $config, 'note' );
    ok( defined $all_notes, 'read_all_meta for notes returns defined' );
    is( scalar @$all_notes, 1, 'read_all_meta returns 1 note' );

    fill_body_for_posts( $all_notes, $site->{ publication_dir } );
    publish_notes_roll( $config, $tt, $all_notes );

    open $fh, '<', "$site->{ publication_dir }/notes_roll.html" or die;
    my $notes_content = do { local $/; <$fh> };
    close $fh;

    like $notes_content, qr/Hello from a test note/,
        'notes roll contains note body';

    teardown_test_site( $site );
}

sub Main {
    test_incremental_all_aggregates_full();
    test_incremental_republish_aggregates();
    test_incremental_archive_no_body();
    test_incremental_front_page_body();
    test_incremental_atom_feed_body();
    test_incremental_notes_aggregates();
    done_testing();
}
