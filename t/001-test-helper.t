use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use TestHelper qw(setup_test_site teardown_test_site test_config);

Main();
exit;

sub Main {
    test_setup_teardown();
    test_test_config();
    done_testing();
}

sub test_setup_teardown {
    my $site = setup_test_site();
    ok -d $site->{ source_dir },      'source dir created';
    ok -d $site->{ publication_dir }, 'publication dir created';
    ok $site->{ tmpdir }, 'tmpdir key exists';

    teardown_test_site( $site );
    ok !-d $site->{ tmpdir }, 'temp dir removed after teardown';
}

sub test_test_config {
    my $config = test_config();
    is ref( $config ), 'HASH', 'config is a hashref';
    ok exists $config->{ source_path },      'config has source_path';
    ok exists $config->{ publication_path }, 'config has publication_path';
    ok exists $config->{ base_uri },         'config has base_uri';
    ok $config->{ base_uri }, 'base_uri is truthy';
}
