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
    test_tags_string_format();
    test_tags_hashref_format();
    test_tags_mixed_format();
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

sub test_tags_string_format {
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
            tags  => [ 'perl', 'python' ]
        ),
    ];

    publish_tags_index( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/data-tag="perl"/,   'string format: perl tag appears';
    like $content, qr/data-tag="python"/, 'string format: python tag appears';

    teardown_test_site( $site );
}

sub test_tags_hashref_format {
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
            tags  => [
                { name => 'perl',   uri => '/tags.html#tag-perl-list' },
                { name => 'python', uri => '/tags.html#tag-python-list' },
            ]
        ),
    ];

    publish_tags_index( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/data-tag="perl"/, 'hashref format: perl tag appears';
    like $content, qr/data-tag="python"/,
        'hashref format: python tag appears';

    teardown_test_site( $site );
}

sub test_tags_mixed_format {
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
            title => 'String Tag Post',
            uri   => '/string.html',
            tags  => [ 'perl' ]
        ),
        _make_post(
            title => 'Hashref Tag Post',
            uri   => '/hashref.html',
            tags  => [
                { name => 'python', uri => '/tags.html#tag-python-list' },
            ]
        ),
    ];

    publish_tags_index( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/tags.html" or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like $content, qr/data-tag="perl"/,   'mixed format: perl tag appears';
    like $content, qr/data-tag="python"/, 'mixed format: python tag appears';

    teardown_test_site( $site );
}
