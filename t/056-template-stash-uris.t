use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test2::V0;

use Burbleboy::Publish ();

Main();
exit;

sub test_stash_uris_are_root_relative {
    my $config = {
        base_uri         => 'https://www.example.com/',
        author_name      => 'Test Author',
        author_email     => 'test@example.com',
        site_description => '',
    };

    my $stash = Burbleboy::Publish::_build_template_stash( $config, undef );

    my @uri_keys = qw(
        frontPage notesRoll archive tagsIndex
        rssFeed jsonFeed notesJSONFeed
        siteCSS siteJS
    );

    for my $key ( @uri_keys ) {
        my $uri     = $stash->{ $key }->{ uri };
        my $uri_str = ref $uri ? "$uri" : $uri;
        ok( $uri_str =~ m{^/},
            "$key uri ($uri_str) is root-relative (starts with /)" )
            or note "Got: $uri_str";
    }
}

sub Main {
    test_stash_uris_are_root_relative();
    done_testing();
}
