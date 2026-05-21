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

sub _setup {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ author_name }      = 'Test Author';
    $config->{ show_max_posts }   = 5;

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    return ( $site, $config, $tt );
}

sub _rebuild_all_aggregates {
    my ( $config, $tt ) = @_;
    my $pub_dir   = $config->{ publication_path };
    my $all_posts = read_all_meta( $config, 'post' );
    my $all_notes = read_all_meta( $config, 'note' );
    if ( @$all_posts ) {
        fill_body_for_top_n( $all_posts, $pub_dir,
            $config->{ show_max_posts } || 5 );
        publish_front_page( $config, $tt, $all_posts );
        publish_archive_page( $config, $tt, $all_posts );
        publish_tags_index( $config, $tt, $all_posts, $all_notes );
        fill_body_for_posts( $all_posts, $pub_dir );
        publish_atom_feed( $config, $tt, $all_posts );
        publish_json_feed( $config, $tt, $all_posts );
    }
    if ( @$all_notes ) {
        fill_body_for_posts( $all_notes, $pub_dir );
        publish_notes_roll( $config, $tt, $all_notes );
        publish_notes_json( $config, $tt, $all_notes );
    }
    return ( $all_posts, $all_notes );
}

sub _slurp {
    my ( $file ) = @_;
    open my $fh, '<', $file or return '';
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

sub test_e2e_fresh_site {
    my ( $site, $config, $tt ) = _setup();

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-fresh.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Fresh Post\ntags: test\n\nHello world.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my ( $all_posts, $all_notes ) = _rebuild_all_aggregates( $config, $tt );

    is( scalar @$all_posts, 1, 'fresh site: 1 post from read_all_meta' );

    my $front = _slurp( "$site->{ publication_dir }/blog.html" );
    like $front, qr/Fresh Post/, 'fresh site: front page shows post';

    my $archive = _slurp( "$site->{ publication_dir }/archive.html" );
    like $archive, qr/Fresh Post/, 'fresh site: archive shows post';

    my $tags = _slurp( "$site->{ publication_dir }/tags.html" );
    like $tags, qr/Fresh Post/, 'fresh site: tags page links to post';

    my $atom = _slurp( "$site->{ publication_dir }/atom.xml" );
    like $atom, qr/Fresh Post/, 'fresh site: atom feed has post';
    like $atom, qr{<content type="html">},
        'fresh site: atom feed has content element';

    my $json = _slurp( "$site->{ publication_dir }/feed.json" );
    like $json, qr/Fresh Post/, 'fresh site: json feed has post';

    teardown_test_site( $site );
}

sub test_e2e_incremental_append {
    my ( $site, $config, $tt ) = _setup();

    my $source_a = "$site->{ source_dir }/2024y01m15d_12h00m00s-post-a.md";
    open my $fh, '>', $source_a or die "Cannot write $source_a: $!";
    print $fh "title: Post A\ntags: perl\n\nBody A.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $source_b = "$site->{ source_dir }/2024y06m15d_12h00m00s-post-b.md";
    open $fh, '>', $source_b or die "Cannot write $source_b: $!";
    print $fh "title: Post B\ntags: perl\n\nBody B.\n";
    close $fh;

    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    _rebuild_all_aggregates( $config, $tt );

    my $front = _slurp( "$site->{ publication_dir }/blog.html" );
    like $front, qr/Post A/, 'incremental append: front page shows Post A';
    like $front, qr/Post B/, 'incremental append: front page shows Post B';
    ok( index( $front, 'Post B' ) < index( $front, 'Post A' ),
        'incremental append: newest first on front page'
    );

    my $archive = _slurp( "$site->{ publication_dir }/archive.html" );
    like $archive, qr/Post A/, 'incremental append: archive shows Post A';
    like $archive, qr/Post B/, 'incremental append: archive shows Post B';

    my $tags = _slurp( "$site->{ publication_dir }/tags.html" );
    like $tags, qr/tag-link/, 'incremental append: tags page has links';

    my $atom = _slurp( "$site->{ publication_dir }/atom.xml" );
    like $atom, qr/Post A/, 'incremental append: atom feed has Post A';
    like $atom, qr/Post B/, 'incremental append: atom feed has Post B';

    my $json = _slurp( "$site->{ publication_dir }/feed.json" );
    like $json, qr/Post A/, 'incremental append: json feed has Post A';
    like $json, qr/Post B/, 'incremental append: json feed has Post B';

    teardown_test_site( $site );
}

sub test_e2e_republish {
    my ( $site, $config, $tt ) = _setup();

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

    my ( $all_posts ) = _rebuild_all_aggregates( $config, $tt );

    is( scalar @$all_posts, 1, 'republish: single post (no duplicate)' );

    my $archive = _slurp( "$site->{ publication_dir }/archive.html" );
    like $archive, qr/Second version/,
        'republish: archive shows updated title';

    my $front = _slurp( "$site->{ publication_dir }/blog.html" );
    like $front, qr/Updated body/, 'republish: front page shows updated body';

    my $atom = _slurp( "$site->{ publication_dir }/atom.xml" );
    like $atom, qr/Second version/,
        'republish: atom feed shows updated title';

    my @entries = $atom =~ /<entry>/g;
    is( scalar @entries, 1, 'republish: single atom entry (no duplicate)' );

    teardown_test_site( $site );
}

sub test_e2e_notes {
    my ( $site, $config, $tt ) = _setup();

    my $notes_dir = "$site->{ source_dir }/notes";
    mkdir $notes_dir or die "Cannot create $notes_dir: $!";

    my $note_source = "$notes_dir/my-test-note.md";
    open my $fh, '>', $note_source or die "Cannot write $note_source: $!";
    print $fh "Hello from an incremental #note.\n";
    close $fh;

    my $orig_cwd = cwd();
    chdir $site->{ publication_dir }
        or die "Cannot chdir to $site->{ publication_dir }: $!";
    incremental_publish_notes( $config, $tt, $notes_dir );
    chdir $orig_cwd;

    my $all_notes = read_all_meta( $config, 'note' );
    is( scalar @$all_notes, 1, 'notes: 1 note from read_all_meta' );

    fill_body_for_posts( $all_notes, $site->{ publication_dir } );
    publish_notes_roll( $config, $tt, $all_notes );
    publish_notes_json( $config, $tt, $all_notes );
    publish_tags_index( $config, $tt, [], $all_notes );

    my $roll = _slurp( "$site->{ publication_dir }/notes_roll.html" );
    like $roll, qr/Hello from an incremental/,
        'notes: notes roll contains note body';

    my $json = _slurp( "$site->{ publication_dir }/recent_notes.json" );
    like $json, qr/Hello from an incremental/,
        'notes: notes json feed contains note body';

    my $tags = _slurp( "$site->{ publication_dir }/tags.html" );
    like $tags, qr/my-test-note/, 'notes: tags page references note';

    teardown_test_site( $site );
}

sub test_e2e_posts_and_notes_tags {
    my ( $site, $config, $tt ) = _setup();

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-tagged.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Tagged Post\ntags: perl\n\nBody.\n";
    close $fh;
    incremental_publish_posts( $config, $tt, $site->{ source_dir } );

    my $notes_dir = "$site->{ source_dir }/notes";
    mkdir $notes_dir or die "Cannot create $notes_dir: $!";

    my $note_source = "$notes_dir/perl-note.md";
    open $fh, '>', $note_source or die "Cannot write $note_source: $!";
    print $fh "This note is about #Perl.\n";
    close $fh;

    my $orig_cwd = cwd();
    chdir $site->{ publication_dir }
        or die "Cannot chdir to $site->{ publication_dir }: $!";
    incremental_publish_notes( $config, $tt, $notes_dir );
    chdir $orig_cwd;

    my $all_posts = read_all_meta( $config, 'post' );
    my $all_notes = read_all_meta( $config, 'note' );

    fill_body_for_posts( $all_posts, $site->{ publication_dir } );
    fill_body_for_posts( $all_notes, $site->{ publication_dir } );
    publish_tags_index( $config, $tt, $all_posts, $all_notes );

    my $tags = _slurp( "$site->{ publication_dir }/tags.html" );
    like $tags, qr/Tagged Post/, 'mixed tags: post appears in tags page';
    like $tags, qr/perl-note/,   'mixed tags: note appears in tags page';

    teardown_test_site( $site );
}

sub test_e2e_empty_fallback {
    my ( $site, $config, $tt ) = _setup();

    publish_front_page( $config, $tt, [] );
    publish_archive_page( $config, $tt, [] );
    publish_tags_index( $config, $tt, [], [] );
    my $front = _slurp( "$site->{ publication_dir }/blog.html" );
    like $front, qr/No posts/, 'empty fallback: front page shows no posts';

    my $archive = _slurp( "$site->{ publication_dir }/archive.html" );
    like $archive, qr/No archive posts/,
        'empty fallback: archive shows no posts';

    my $tags = _slurp( "$site->{ publication_dir }/tags.html" );
    like $tags, qr/No tags/, 'empty fallback: tags page shows no tags';

    teardown_test_site( $site );
}

sub Main {
    test_e2e_fresh_site();
    test_e2e_incremental_append();
    test_e2e_republish();
    test_e2e_notes();
    test_e2e_posts_and_notes_tags();
    test_e2e_empty_fallback();
    done_testing();
}
