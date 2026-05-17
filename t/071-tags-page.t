use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(publish_tags_index);

Main();
exit;

sub Main {
    test_tags_grouped_by_letter();
    test_tags_single_tag();
    test_tags_no_posts();
    test_tags_no_tags();
    test_tags_multiple_per_post();
    test_tags_with_notes();
    done_testing();
}

sub _make_note {
    my ( %args ) = @_;
    return {
        body_html => $args{ body } || '<p>Note body</p>',
        body      => $args{ body } || 'Note body',
        date      => $args{ date } || 1717344000,
        uri       => $args{ uri }  || '/notes/test-note.html',
        tags      => $args{ tags } // [],
        title     => $args{ title },
        %args,
    };
}

sub test_tags_with_notes {
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
            title => 'Perl Post',
            uri   => '/perl-post.html',
            tags  => [ 'Perl' ]
        ),
    ];

    my $notes = [
        _make_note(
            uri  => '/notes/perl-note.html',
            tags => [ 'perl' ],
        ),
    ];

    publish_tags_index( $config, $tt, $posts, $notes );

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr{Perl Post}, 'post title appears in tags index';
    like $content, qr{Note body\.\.\.},
        'note body fallback title appears in tags index';
    like $content, qr{data-tag="perl".*data-count="2"}s,
        'both post and note grouped under same normalized tag';

    teardown_test_site( $site );
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

sub test_tags_grouped_by_letter {
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
            title => 'Perl Post',
            uri   => '/perl.html',
            tags  => [ 'perl' ]
        ),
        _make_post(
            title => 'Python Post',
            uri   => '/python.html',
            tags  => [ 'python' ]
        ),
        _make_post(
            title => 'JS Post',
            uri   => '/js.html',
            tags  => [ 'javascript' ]
        ),
    ];

    publish_tags_index( $config, $tt, $posts );

    ok -e "$site->{ publication_dir }/tags.html",
        'tags.html created by publish_tags_index';

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/data-letter="P".*data-tag="perl"/s,
        'perl grouped under P';
    like $content, qr/data-letter="P".*data-tag="python"/s,
        'python grouped under P';
    like $content, qr/data-letter="J".*data-tag="javascript"/s,
        'javascript grouped under J';

    teardown_test_site( $site );
}

sub test_tags_single_tag {
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
            title => 'Only Perl',
            uri   => '/only-perl.html',
            tags  => [ 'perl' ]
        ),
    ];

    publish_tags_index( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr{data-tag="perl".*data-count="1"}s,
        'single tag has count of 1';

    teardown_test_site( $site );
}

sub test_tags_no_posts {
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

    publish_tags_index( $config, $tt, [] );

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/No tags/, 'tags page with no posts shows empty state';

    teardown_test_site( $site );
}

sub test_tags_no_tags {
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
            title => 'No Tags Post',
            uri   => '/no-tags.html',
            tags  => []
        ),
    ];

    publish_tags_index( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/No tags/, 'posts with no tags result in no tag groups';

    teardown_test_site( $site );
}

sub test_tags_multiple_per_post {
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
            title => 'Multi Tag',
            uri   => '/multi.html',
            tags  => [ 'perl', 'javascript', 'testing' ]
        ),
    ];

    publish_tags_index( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/data-tag="perl"/,       'perl tag from multi-tag post';
    like $content, qr/data-tag="javascript"/, 'javascript tag appears';
    like $content, qr/data-tag="testing"/,    'testing tag appears';

    teardown_test_site( $site );
}
