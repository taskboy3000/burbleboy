use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Spec;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(publish_post needs_update try_publish);

Main();
exit;

sub test_try_publish_success {
    my $result = try_publish( 'test', sub { return 'ok' } );
    is( $result, 'ok', 'try_publish returns result on success' );
}

sub test_try_publish_catches_die {
    my $result = try_publish( 'test', sub { die 'oh no' } );
    ok( !defined $result, 'try_publish returns undef on die' );
}

sub test_try_publish_verbose_warns {
    my $warn;
    local $SIG{ __WARN__ } = sub { $warn = shift };
    try_publish( 'test-op', sub { die 'fail' }, 1 );
    like( $warn, qr/test-op/, 'try_publish warns with label on verbose' );
}

sub Main {
    test_needs_update_no_output();
    test_needs_update_source_newer();
    test_needs_update_source_older();
    test_fresh_publish();
    test_republish();
    test_skip();
    test_missing_source();
    test_bad_template();
    test_emoji_in_post();
    test_try_publish_success();
    test_try_publish_catches_die();
    test_try_publish_verbose_warns();
    done_testing();
}

sub _write_minimal_templates {
    my ( $dir ) = @_;

    open my $fh, '>', "$dir/layout.tt" or die "Cannot write layout.tt: $!";
    print $fh <<'EOF';
<!DOCTYPE html>
<html lang="en">
<head><title>[% config.title %] :: [% section_title | html %]</title></head>
<body>
[% content %]
</body>
</html>
EOF
    close $fh;

    open $fh, '>', "$dir/single_post.tt"
        or die "Cannot write single_post.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' section_title = post.title %]
<article>
<h1>[% post.title %]</h1>
<div>[% post.body %]</div>
</article>
[% END %]
EOF
    close $fh;
}

sub test_needs_update_no_output {
    my $source = "$FindBin::Bin/tmp_needs_update_$$";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Test\n\nBody\n";
    close $fh;

    ok( needs_update( $source, '/nonexistent/output.html' ),
        'needs_update true when output missing' );

    unlink $source;
}

sub test_needs_update_source_newer {
    my $source = "$FindBin::Bin/tmp_source_newer_$$";
    my $output = "$FindBin::Bin/tmp_output_older_$$";

    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Test\n\nBody\n";
    close $fh;

    open $fh, '>', $output or die "Cannot write $output: $!";
    print $fh "old content";
    close $fh;

    utime( time - 100, time - 100, $output );

    ok( needs_update( $source, $output ),
        'needs_update true when source newer than output' );

    unlink $source, $output;
}

sub test_needs_update_source_older {
    my $source = "$FindBin::Bin/tmp_source_older_$$";
    my $output = "$FindBin::Bin/tmp_output_newer_$$";

    open my $fh, '>', $output or die "Cannot write $output: $!";
    print $fh "newer content";
    close $fh;

    open $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Test\n\nBody\n";
    close $fh;

    utime( time - 200, time - 200, $source );

    ok( !needs_update( $source, $output ),
        'needs_update false when source older than output' );

    unlink $source, $output;
}

sub test_fresh_publish {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-fresh.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Fresh Post\n\nHello world.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $post = publish_post( $source, $config, $tt );

    ok( -e $post->{ publication_file },
        'output file created on fresh publish'
    );

    open $fh, '<', $post->{ publication_file } or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/Fresh Post/,  'post title appears in output' );
    like( $content, qr/Hello world/, 'post body appears in output' );

    teardown_test_site( $site );
}

sub test_republish {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y02m20d_10h00m00s-repub.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Republish\n\nOriginal content.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $post     = publish_post( $source, $config, $tt );
    my $pub_file = $post->{ publication_file };

    sleep 1;

    open $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Republish\n\nUpdated content.\n";
    close $fh;

    ok( needs_update( $source, $pub_file ),
        'needs_update true after source update'
    );

    publish_post( $source, $config, $tt );

    open $fh, '<', $pub_file or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/Updated content/, 'republished with new content' );

    teardown_test_site( $site );
}

sub test_skip {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y03m10d_08h00m00s-skip.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Skip\n\nOriginal.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $post     = publish_post( $source, $config, $tt );
    my $pub_file = $post->{ publication_file };

    ok( -e $pub_file, 'output exists after first publish' );

    utime( time - 200, time - 200, $source );

    ok( !needs_update( $source, $pub_file ),
        'needs_update false when source older than output' );

    teardown_test_site( $site );
}

sub test_emoji_in_post {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y07m01d_12h00m00s-emoji.md";
    open my $fh, '>:utf8', $source or die "Cannot write $source: $!";
    print $fh "title: Emoji Post\n\nCat emoji: \x{1F63A}\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $warnings = '';
    local $SIG{ __WARN__ } = sub { $warnings .= shift };

    my $post = publish_post( $source, $config, $tt );

    is( $warnings, '', 'no warnings during publish_post with emoji' );

    ok( -e $post->{ publication_file },
        'output file created for emoji post' );

    open $fh, '<:encoding(UTF-8)', $post->{ publication_file } or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/Cat emoji:/, 'post body contains emoji label' );
    like( $content, qr/\x{1F63A}/, 'post output contains emoji character' );

    teardown_test_site( $site );
}

sub test_missing_source {
    my $config = test_config();
    my $tt     = Template->new();

    like( dies { publish_post( '/nonexistent/file.md', $config, $tt ) },
        qr/not found/i, 'dies on missing source file' );
}

sub test_bad_template {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y04m05d_06h00m00s-badtmpl.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Bad Template\n\nBody.\n";
    close $fh;

    my $tt = Template->new( { INCLUDE_PATH => '/nonexistent' } );

    like( dies { publish_post( $source, $config, $tt ) },
        qr/error/i, 'dies on template error' );

    teardown_test_site( $site );
}
