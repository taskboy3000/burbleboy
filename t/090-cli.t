use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Spec;
use TestHelper qw(setup_test_site teardown_test_site test_config);

Main();
exit;

sub Main {
    test_compile();
    test_help_output();
    test_version_output();
    test_unknown_flag();
    test_publish_all_with_config();
    test_publish_only_posts();
    test_publish_only_notes();
    test_force_flag();
    test_verbose_flag();
    test_lock_file_location();
    done_testing();
}

sub test_lock_file_location {
    my $site = setup_test_site();
    _write_config( $site->{ tmpdir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_SOURCE', $site->{ source_dir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_PUB', $site->{ publication_dir } );
    _write_source_post( $site->{ source_dir } );

    local $ENV{ HOME } = $site->{ tmpdir };

    my $output = `perl "$FindBin::Bin/../bin/burbleboycmd" --publish-all 2>&1`;
    is( $?, 0, '--publish-all exits 0' ) or diag $output;

    ok( -f "$site->{ publication_dir }/.burbleboycmd.lock",
        'lock file created in publication directory'
    );

    teardown_test_site( $site );
}

sub _write_config {
    my ( $dir ) = @_;

    open my $fh, '>', "$dir/.burbleboy.conf"
        or die "Cannot write .burbleboy.conf: $!";
    print $fh <<'END_CONF';
base_uri: http://example.com
title: CLI Test
author_name: Test Author
author_email: test@example.com
source_path: REPLACE_SOURCE
publication_path: REPLACE_PUB
END_CONF
    close $fh;
}

sub _write_source_post {
    my ( $dir, $name, $title ) = @_;
    $name  //= '2024y01m15d_12h00m00s-test-post.md';
    $title //= 'Test Post';
    open my $fh, '>', "$dir/$name" or die "Cannot write $name: $!";
    print $fh "title: $title\n\nBody of $title.\n";
    close $fh;
}

sub _write_source_note {
    my ( $dir, $name ) = @_;
    $name //= '2024y01m15d_13h00m00s-test-note.md';
    open my $fh, '>', "$dir/$name" or die "Cannot write $name: $!";
    print $fh "Note body text.\n";
    close $fh;
}

sub _replace_in_file {
    my ( $file, $old, $new ) = @_;
    open my $fh, '<', $file or die "Cannot read $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    $content =~ s/\Q$old\E/$new/g;
    open $fh, '>', $file or die "Cannot write $file: $!";
    print $fh $content;
    close $fh;
}

sub test_compile {
    my $output = `perl -c "$FindBin::Bin/../bin/burbleboycmd" 2>&1`;
    is( $?, 0, 'burbleboycmd compiles' )
        or diag $output;
}

sub test_help_output {
    my $output = `perl "$FindBin::Bin/../bin/burbleboycmd" --help 2>&1`;
    is( $?, 0, '--help exits 0' );
    like( $output, qr/USAGE|COMMAND|OPTIONS/i, '--help shows usage' );
    like( $output, qr/publish-all/,            '--help lists publish-all' );
    like( $output, qr/publish-only-posts/,
        '--help lists publish-only-posts' );
    like( $output, qr/publish-only-notes/,
        '--help lists publish-only-notes' );
}

sub test_version_output {
    my $output = `perl "$FindBin::Bin/../bin/burbleboycmd" --version 2>&1`;
    is( $?, 0, '--version exits 0' );
}

sub test_unknown_flag {
    my $output = `perl "$FindBin::Bin/../bin/burbleboycmd" --unknown-flag 2>&1`;
    isnt( $?, 0, 'unknown flag exits non-zero' );
}

sub test_publish_all_with_config {
    my $site = setup_test_site();
    _write_config( $site->{ tmpdir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_SOURCE', $site->{ source_dir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_PUB', $site->{ publication_dir } );
    _write_source_post( $site->{ source_dir } );

    local $ENV{ HOME } = $site->{ tmpdir };

    my $output = `perl "$FindBin::Bin/../bin/burbleboycmd" --publish-all 2>&1`;
    is( $?, 0, '--publish-all exits 0' ) or diag $output;

    ok( -e "$site->{ publication_dir }/2024y01m15d_12h00m00s-test-post.html",
        'post HTML file created'
    );

    teardown_test_site( $site );
}

sub test_publish_only_posts {
    my $site = setup_test_site();
    _write_config( $site->{ tmpdir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_SOURCE', $site->{ source_dir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_PUB', $site->{ publication_dir } );
    _write_source_post( $site->{ source_dir } );

    local $ENV{ HOME } = $site->{ tmpdir };

    my $output =
        `perl "$FindBin::Bin/../bin/burbleboycmd" --publish-only-posts 2>&1`;
    is( $?, 0, '--publish-only-posts exits 0' ) or diag $output;

    ok( -e "$site->{ publication_dir }/2024y01m15d_12h00m00s-test-post.html",
        'post HTML file created from --publish-only-posts'
    );

    teardown_test_site( $site );
}

sub test_publish_only_notes {
    my $site = setup_test_site();
    _write_config( $site->{ tmpdir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_SOURCE', $site->{ source_dir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_PUB', $site->{ publication_dir } );
    _write_source_note( $site->{ source_dir } );

    local $ENV{ HOME } = $site->{ tmpdir };

    my $output =
        `perl "$FindBin::Bin/../bin/burbleboycmd" --publish-only-notes 2>&1`;
    is( $?, 0, '--publish-only-notes exits 0' ) or diag $output;

    ok( -e "$site->{ publication_dir }", 'publication directory exists' );

    teardown_test_site( $site );
}

sub test_force_flag {
    my $site = setup_test_site();
    _write_config( $site->{ tmpdir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_SOURCE', $site->{ source_dir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_PUB', $site->{ publication_dir } );
    _write_source_post( $site->{ source_dir } );

    local $ENV{ HOME } = $site->{ tmpdir };

    my $output =
        `perl "$FindBin::Bin/../bin/burbleboycmd" --publish-all --force 2>&1`;
    is( $?, 0, '--publish-all --force exits 0' ) or diag $output;

    ok( -e "$site->{ publication_dir }/2024y01m15d_12h00m00s-test-post.html",
        'post HTML file created with --force'
    );

    teardown_test_site( $site );
}

sub test_verbose_flag {
    my $site = setup_test_site();
    _write_config( $site->{ tmpdir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_SOURCE', $site->{ source_dir } );
    _replace_in_file( "$site->{ tmpdir }/.burbleboy.conf",
        'REPLACE_PUB', $site->{ publication_dir } );
    _write_source_post( $site->{ source_dir } );

    local $ENV{ HOME } = $site->{ tmpdir };

    my $output =
        `perl "$FindBin::Bin/../bin/burbleboycmd" --publish-all --verbose 2>&1`;
    is( $?, 0, '--publish-all --verbose exits 0' ) or diag $output;

    teardown_test_site( $site );
}
