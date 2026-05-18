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
    test_new_file_processed();
    test_modified_file_processed();
    test_stale_file_skipped();
    done_testing();
}

sub _write_minimal_templates {
    my ( $dir ) = @_;
    open my $fh, '>', "$dir/layout.tt" or die;
    print $fh '<html><body>[% content %]</body></html>';
    close $fh;
    open $fh, '>', "$dir/single_post.tt" or die;
    print $fh
        '<article><h1>[% post.title %]</h1><div>[% post.body %]</div></article>';
    close $fh;
}

sub test_new_file_processed {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-new-file.md";
    open my $fh, '>', $source or die;
    print $fh "title: New File\n\nBody content.\n";
    close $fh;

    my $result =
        incremental_publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result,         1,          'new file is processed' );
    is( $result->[ 0 ]{ title }, 'New File', 'new file has correct title' );

    teardown_test_site( $site );
}

sub test_modified_file_processed {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y02m10d_08h30m00s-modified.md";
    open my $fh, '>', $source or die;
    print $fh "title: Modified File\n\nOld content.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    sleep 1;
    open $fh, '>', $source or die;
    print $fh "title: Modified File\n\nNew content.\n";
    close $fh;

    my $result =
        incremental_publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result, 1, 'modified file is processed' );

    teardown_test_site( $site );
}

sub test_stale_file_skipped {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    _write_minimal_templates( $site->{ tmpdir } );
    my $tt =
        Template->new( { INCLUDE_PATH => $site->{ tmpdir }, ABSOLUTE => 1 } );

    my $source = "$site->{ source_dir }/2024y03m20d_14h15m00s-stale.md";
    open my $fh, '>', $source or die;
    print $fh "title: Stale File\n\nBody.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    utime( time - 200, time - 200, $source );

    my $result =
        incremental_publish_posts( $config, $tt, $site->{ source_dir } );
    is( scalar @$result, 0, 'stale file is skipped' );

    teardown_test_site( $site );
}
