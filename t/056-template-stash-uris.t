use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test2::V0;

use Burbleboy::Publish ();

Main();
exit;

sub _make_config {
    my ( $base_uri ) = @_;
    return {
        base_uri         => $base_uri || 'https://www.example.com/',
        author_name      => 'Test Author',
        author_email     => 'test@example.com',
        site_description => '',
    };
}

sub _check_uris {
    my ( $stash, $desc, $expect_prefix ) = @_;

    my @uri_keys = qw(
        frontPage notesRoll archive tagsIndex
        rssFeed jsonFeed notesJSONFeed
        siteCSS siteJS
    );

    my @expected = (
        $expect_prefix . 'blog.html',
        $expect_prefix . 'notes_roll.html',
        $expect_prefix . 'archive.html',
        $expect_prefix . 'tags.html',
        $expect_prefix . 'atom.xml',
        $expect_prefix . 'feed.json',
        $expect_prefix . 'recent_notes.json',
        $expect_prefix . 'css/site.css',
        $expect_prefix . 'js/site.js',
    );

    for my $i ( 0 .. $#uri_keys ) {
        my $key = $uri_keys[ $i ];
        my $uri = $stash->{ $key }->{ uri };
        my $got = ref $uri ? "$uri" : $uri;
        is( $got, $expected[ $i ], "$desc: $key uri is '$expected[$i]'" );
    }
}

sub test_root_page_uris {
    my $stash =
        Burbleboy::Publish::_build_template_stash( _make_config(), undef );
    _check_uris( $stash, 'root page', '' );
}

sub test_notes_page_uris {
    my $stash = Burbleboy::Publish::_build_template_stash( _make_config(),
        'https://www.example.com/notes/some-note.html' );
    _check_uris( $stash, 'notes page', '../' );
}

sub test_dev_subdirectory_uris {
    my $stash = Burbleboy::Publish::_build_template_stash(
        _make_config( 'http://localhost/~user/blog/' ),
        'http://localhost/~user/blog/notes/some-note.html'
    );
    _check_uris( $stash, 'notes page with subdir base', '../' );
}

sub test_dev_root_page_subdirectory_base {
    my $stash = Burbleboy::Publish::_build_template_stash(
        _make_config( 'http://localhost/~user/blog/' ),
        'http://localhost/~user/blog/some-post.html'
    );
    _check_uris( $stash, 'root page with subdir base', '' );
}

sub Main {
    test_root_page_uris();
    test_notes_page_uris();
    test_dev_subdirectory_uris();
    test_dev_root_page_subdirectory_base();
    done_testing();
}
