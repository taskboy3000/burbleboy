use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use Cwd qw(cwd);
use File::Spec;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(republish_source read_all_meta);

Main();
exit;

sub Main {
    test_republish_post();
    test_republish_note();
    test_republish_missing_file();
    done_testing();
}

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

    open $fh, '>', "$dir/single_post.tt" or die "Cannot write single_post.tt: $!";
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

    open $fh, '>', "$dir/front_page.tt" or die "Cannot write front_page.tt: $!";
    print $fh <<'EOF';
[% WRAPPER layout.tt %]
[% IF posts.size > 0 %]
[% FOREACH p = posts %]
<div class="post">[% p.title %]</div>
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
[% FOREACH p = posts %]
<div class="archive-entry">[% p.title %]</div>
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

    open $fh, '>', "$dir/feed.tt" or die "Cannot write feed.tt: $!";
    print $fh <<'EOF';
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>[% config.title %]</title>
[% FOR post IN posts %]
  <entry><title>[% post.title %]</title></entry>
[% END %]
</feed>
EOF
    close $fh;

    open $fh, '>', "$dir/notes_roll.tt" or die "Cannot write notes_roll.tt: $!";
    print $fh <<'EOF';
[% IF notes.size > 0 -%]
  [% FOREACH note = notes %]
    <div class="note">[% note.body_html %]</div>
  [% END %]
[% ELSE %]
  <em>No notes posted yet.</em>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/site_css.tt" or die "Cannot write site_css.tt: $!";
    print $fh "/* css */\n";
    close $fh;

    open $fh, '>', "$dir/site_js.tt" or die "Cannot write site_js.tt: $!";
    print $fh "// js\n";
    close $fh;
}

sub test_republish_post {
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

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-repubfn.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: First\ntags: t\n\nOriginal body.\n";
    close $fh;

    # first publish via republish_source
    republish_source( $source, $config, $tt, { verbose => 0 } );

    ok( -e "$site->{ publication_dir }/blog.html", 'blog.html exists after first republish' );
    ok( -e "$site->{ publication_dir }/archive.html", 'archive.html exists after first republish' );

    sleep 1;
    open $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Second\ntags: t\n\nUpdated body.\n";
    close $fh;

    republish_source( $source, $config, $tt, { verbose => 0 } );

    open $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $front = do { local $/; <$fh> };
    close $fh;
    like $front, qr/Second/, 'front page shows updated title after republish_source';

    my $all = read_all_meta( $config, 'post' );
    is( scalar @$all, 1, 'republish_source keeps single meta entry' );

    teardown_test_site( $site );
}

sub test_republish_note {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ author_name }      = 'Test Author';
    $config->{ show_max_posts }   = 5;
    # Notes source dir is source_dir/notes by default
    my $notes_dir_src = "$site->{ source_dir }/notes";
    mkdir $notes_dir_src or die "Cannot create $notes_dir_src: $!";
    $config->{ source_notes_directory } = $notes_dir_src;

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$notes_dir_src/repub-note.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "First note body.\n";
    close $fh;

    republish_source( $source, $config, $tt, { verbose => 0 } );

    ok( -e "$site->{ publication_dir }/notes_roll.html", 'notes_roll.html exists after republish note' );

    my $notes_dir_pub = "$site->{ publication_dir }/notes";
    ok( -d $notes_dir_pub, 'notes pub dir exists' );
    opendir my $dh, $notes_dir_pub or die "Cannot open notes dir: $!";
    my @note_htmls = grep { /\.html$/ && -f "$notes_dir_pub/$_" } readdir($dh);
    closedir $dh;
    is( scalar @note_htmls, 1, 'one note html published' );

    open $fh, '<', "$notes_dir_pub/$note_htmls[0]" or die;
    my $note_html = do { local $/; <$fh> };
    close $fh;
    like $note_html, qr/First note body/, 'note html has first body';

    sleep 1;
    open $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "Second note body.\n";
    close $fh;

    republish_source( $source, $config, $tt, { verbose => 0 } );

    opendir $dh, $notes_dir_pub or die;
    @note_htmls = grep { /\.html$/ && -f "$notes_dir_pub/$_" } readdir($dh);
    closedir $dh;
    is( scalar @note_htmls, 1, 'still one note html after republish' );

    open $fh, '<', "$notes_dir_pub/$note_htmls[0]" or die;
    $note_html = do { local $/; <$fh> };
    close $fh;
    like $note_html, qr/Second note body/, 'note html has updated body after republish_source';

    teardown_test_site( $site );
}

sub test_republish_missing_file {
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

    my $missing = "$site->{ source_dir }/does-not-exist.md";
    my $ok = eval { republish_source( $missing, $config, $tt, {} ); 1 };
    my $err = $@;
    ok( !$ok, 'republish_source dies for missing file' );
    like( $err, qr/not found|not exist|Source file not found/i, 'error mentions missing file' );

    teardown_test_site( $site );
}

sub Main {
    test_republish_post();
    test_republish_note();
    test_republish_missing_file();
    done_testing();
}