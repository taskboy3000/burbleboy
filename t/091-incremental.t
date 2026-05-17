use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(incremental_publish_posts publish_post);

Main();
exit;

sub Main {
    test_no_new_posts_noop();
    test_one_new_post();
    test_updated_post();
    test_source_older_skipped();
    test_source_newer_publishes();
    done_testing();
}

sub _write_templates {
    my ( $dir ) = @_;
    open my $fh, '>', "$dir/layout.tt" or die "Cannot write layout.tt: $!";
    print $fh <<'EOF';
<!DOCTYPE html>
<html><body>[% content %]</body></html>
EOF
    close $fh;

    open $fh, '>', "$dir/single_post.tt"
        or die "Cannot write single_post.tt: $!";
    print $fh <<'EOF';
<article><h1>[% post.title %]</h1><div>[% post.body %]</div></article>
EOF
    close $fh;
}

sub test_no_new_posts_noop {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    _write_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-noop.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Noop\n\nBody.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    utime( time - 200, time - 200, $source );

    my $result =
        incremental_publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result, 0, 'noop: no posts published when source older' );

    teardown_test_site( $site );
}

sub test_one_new_post {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    _write_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y02m10d_08h30m00s-new.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: New Post\n\nContent.\n";
    close $fh;

    my $result =
        incremental_publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result,         1,          'newpost: one post published' );
    is( $result->[ 0 ]{ title }, 'New Post', 'newpost: correct title' );

    ok( -e $result->[ 0 ]{ publication_file },
        'newpost: output file exists' );

    teardown_test_site( $site );
}

sub test_updated_post {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    _write_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y03m20d_14h15m00s-upd.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Updated\n\nOld content.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    sleep 1;

    open $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Updated\n\nNew content.\n";
    close $fh;

    my $result =
        incremental_publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result, 1, 'updated: post republished' );

    teardown_test_site( $site );
}

sub test_source_older_skipped {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    _write_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y04m05d_09h00m00s-old.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Old Source\n\nBody.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    sleep 1;
    utime( time - 100, time - 100, $source );

    my $result =
        incremental_publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result, 0, 'older: skipped when source older' );

    teardown_test_site( $site );
}

sub test_source_newer_publishes {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    _write_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y05m10d_11h00m00s-fresh.md";
    open my $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Fresh\n\nContent.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    sleep 1;

    open $fh, '>', $source or die "Cannot write source: $!";
    print $fh "title: Fresh\n\nUpdated content.\n";
    close $fh;

    my $result =
        incremental_publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result, 1, 'newer: source newer published' );

    teardown_test_site( $site );
}
