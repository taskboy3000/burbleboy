use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(publish_front_page publish_archive_page publish_note);
use Burbleboy::Model::Note qw(parse_note);

Main();
exit;

sub Main {
    test_front_page_with_posts();
    test_front_page_no_posts();
    test_front_page_respects_max();
    test_archive_grouped_by_month();
    test_archive_single_post();
    test_archive_no_posts();
    test_front_page_shows_notes();
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

    open $fh, '>', "$dir/front_page.tt"
        or die "Cannot write front_page.tt: $!";
    print $fh <<'EOF';
[% WRAPPER layout.tt %]
[% IF posts.size > 0 %]
[% FOREACH p = posts %]
<div class="post">[% p._type || 'post' %]: [% p.title %] - [% p.date %]</div>
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
}

sub _make_post {
    my ( %args ) = @_;
    return {
        title        => $args{ title } || 'Test Post',
        body_html    => $args{ body }  || '<p>Body</p>',
        date         => $args{ date }  || '2024-01-15T12:00:00',
        uri          => $args{ uri }   || '/post.html',
        tags         => $args{ tags }         // [],
        reading_time => $args{ reading_time } // 1,
        year         => $args{ year }       || '2024',
        month        => $args{ month }      || '01',
        month_name   => $args{ month_name } || 'January',
        %args,
    };
}

sub test_front_page_with_posts {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ show_max_posts }   = 5;

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $posts = [
        _make_post( title => 'Post B', date => '2024-06-15T12:00:00' ),
        _make_post( title => 'Post A', date => '2024-01-15T12:00:00' ),
    ];

    publish_front_page( $config, $tt, $posts );

    ok -e "$site->{ publication_dir }/blog.html",
        'blog.html created by publish_front_page';

    open my $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/Post B/, 'newest post appears first';
    like $content, qr/Post A/, 'older post appears';
    ok( ( $content =~ /Post B/gm && $content =~ /Post A/gm )
            && index( $content, 'Post B' ) < index( $content, 'Post A' ),
        'posts sorted in descending date order'
    );

    teardown_test_site( $site );
}

sub test_front_page_no_posts {
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

    publish_front_page( $config, $tt, [] );

    open my $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/No posts/, 'front page shows empty state with 0 posts';

    teardown_test_site( $site );
}

sub test_front_page_respects_max {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ show_max_posts }   = 2;

    _write_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $posts = [
        _make_post( title => 'Post C', date => '2024-03-15T12:00:00' ),
        _make_post( title => 'Post B', date => '2024-02-15T12:00:00' ),
        _make_post( title => 'Post A', date => '2024-01-15T12:00:00' ),
    ];

    publish_front_page( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content,   qr/Post C/, 'first post appears (show_max_posts=2)';
    like $content,   qr/Post B/, 'second post appears';
    unlike $content, qr/Post A/, 'third post excluded by show_max_posts';

    teardown_test_site( $site );
}

sub test_archive_grouped_by_month {
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

    my $posts = [
        _make_post(
            title      => 'Jan Post',
            date       => '2024-01-15T12:00:00',
            year       => '2024',
            month      => '01',
            month_name => 'January'
        ),
        _make_post(
            title      => 'Feb Post',
            date       => '2024-02-10T08:00:00',
            year       => '2024',
            month      => '02',
            month_name => 'February'
        ),
        _make_post(
            title      => 'Mar Post',
            date       => '2024-03-20T14:00:00',
            year       => '2024',
            month      => '03',
            month_name => 'March'
        ),
    ];

    publish_archive_page( $config, $tt, $posts );

    ok -e "$site->{ publication_dir }/archive.html",
        'archive.html created by publish_archive_page';

    open my $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/Jan Post/, 'January post in archive';
    like $content, qr/Feb Post/, 'February post in archive';
    like $content, qr/Mar Post/, 'March post in archive';
    like $content, qr{2024/01},  'archive shows year/month for Jan';
    like $content, qr{2024/02},  'archive shows year/month for Feb';
    like $content, qr{2024/03},  'archive shows year/month for Mar';

    teardown_test_site( $site );
}

sub test_archive_single_post {
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

    my $posts = [
        _make_post(
            title      => 'Only Post',
            date       => '2024-06-01T00:00:00',
            year       => '2024',
            month      => '06',
            month_name => 'June'
        ),
    ];

    publish_archive_page( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/Only Post/, 'single post appears in archive';
    like $content, qr{2024/06},   'archive shows correct year/month';

    teardown_test_site( $site );
}

sub test_archive_no_posts {
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

    publish_archive_page( $config, $tt, [] );

    open my $fh, '<', "$site->{ publication_dir }/archive.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/No archive posts/,
        'archive shows empty state with 0 posts';

    teardown_test_site( $site );
}

sub test_front_page_shows_notes {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path }      = $site->{ publication_dir };
    $config->{ publication_directory } = $site->{ publication_dir };

    _write_templates( $site->{ tmpdir } );

    open my $fh, '>', "$site->{ tmpdir }/note.tt"
        or die "Cannot write note.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<div class="note"><!-- POST_BODY_START --><div class="e-content">[% note.body %]</div><!-- POST_BODY_END --></div>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$site->{ tmpdir }/single_post.tt"
        or die "Cannot write single_post.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' %]
<article><h1>[% post.title %]</h1><!-- POST_BODY_START --><div class="body e-content">[% post.body %]</div><!-- POST_BODY_END --></article>
[% END %]
EOF
    close $fh;

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $post_source = "$site->{ source_dir }/2024y01m15d_12h00m00s-old-post.md";
    open $fh, '>', $post_source or die "Cannot write $post_source: $!";
    print $fh "title: Old Post\n\nOlder content.\n";
    close $fh;

    my $note_source = "$site->{ source_dir }/old-note.md";
    open $fh, '>', $note_source or die "Cannot write $note_source: $!";
    print $fh "This is a more recent note.\n";
    close $fh;

    require Burbleboy::Publish;
    Burbleboy::Publish::publish_note( $note_source, $config, $tt );
    Burbleboy::Publish::publish_post( $post_source, $config, $tt );

    my $all_posts = Burbleboy::Publish::read_all_meta( $config, 'post' );
    publish_front_page( $config, $tt, $all_posts );

    open $fh, '<', "$site->{ publication_dir }/blog.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/old note/i,
        'front page shows note in merged stream';
    like $content, qr/Old Post/i,
        'front page shows post alongside note';

    teardown_test_site( $site );
}
