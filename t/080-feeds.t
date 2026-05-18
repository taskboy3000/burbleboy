use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Spec;
use Template;
use JSON;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(publish_atom_feed publish_json_feed);

Main();
exit;

sub Main {
    test_escape_cdata();
    test_atom_multiple_posts();
    test_atom_zero_posts();
    test_atom_one_post();
    test_atom_cdata_escaping();
    test_json_multiple_posts();
    test_json_zero_posts();
    test_json_one_post();
    test_json_truncation();
    done_testing();
}

sub test_escape_cdata {
    my $got = Burbleboy::Publish::_escape_cdata( undef );
    is( $got, '', '_escape_cdata(undef) returns empty string' );

    $got = Burbleboy::Publish::_escape_cdata( 'plain text' );
    is( $got, 'plain text', '_escape_cdata leaves plain text unchanged' );

    $got = Burbleboy::Publish::_escape_cdata( 'a ]]> b' );
    is( $got, 'a ]]]]><![CDATA[> b',
        '_escape_cdata splits ]]> across CDATA boundaries' );

    $got = Burbleboy::Publish::_escape_cdata( ']]>x2]]>' );
    is( $got,
        ']]]]><![CDATA[>x2]]]]><![CDATA[>',
        '_escape_cdata handles multiple ]]> sequences' );
}

sub _write_feed_templates {
    my ( $dir ) = @_;

    open my $fh, '>', "$dir/feed.tt" or die "Cannot write feed.tt: $!";
    print $fh <<'EOF';
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title><![CDATA[[% feed_title %]]]></title>
  <link href="[% config.base_uri %]/atom.xml" rel="self" />
  <link href="[% config.base_uri %]" />
  <updated>[% timestamp %]</updated>
  <id>[% config.base_uri %]</id>
  <author>
    <name><![CDATA[[% feed_author %]]]></name>
    <email><![CDATA[[% feed_email %]]]></email>
  </author>
[% FOR post IN posts %]
  <entry>
    <title type="html"><![CDATA[[% post.title %]]]></title>
    <link href="[% post.uri %]"/>
    <published>[% post.published_timestamp %]</published>
    <updated>[% post.updated_timestamp %]</updated>
    <id>[% post.uri %]</id>
    <content type="html"><![CDATA[[% post.body %]]]></content>
  </entry>
[% END %]
</feed>
EOF
    close $fh;

}

sub _make_posts {
    my ( $count ) = @_;
    my @posts;
    for my $i ( 1 .. $count ) {
        my $day = sprintf( "%02d", $i );
        push @posts,
            {
            title     => "Post $i",
            uri       => "http://example.com/post-$i.html",
            date      => "2024-01-${day}T12:00:00",
            body_html => "<p>Body $i</p>",
            };
    }
    return \@posts;
}

sub test_atom_multiple_posts {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ author_name }      = 'Test Author';

    _write_feed_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $posts = _make_posts( 3 );
    publish_atom_feed( $config, $tt, $posts );

    my $file = "$site->{ publication_dir }/atom.xml";
    ok( -e $file, 'atom.xml created' );

    open my $fh, '<', $file or die "Cannot read $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/<\?xml/,  'XML declaration present' );
    like( $content, qr/<feed/,   'feed element present' );
    like( $content, qr/Post 1/,  'first post title in feed' );
    like( $content, qr/Post 3/,  'last post title in feed' );
    like( $content, qr/<entry>/, 'entry element present' );

    my @entries = $content =~ /<entry>/g;
    is( scalar @entries, 3, '3 entries in Atom feed' );

    teardown_test_site( $site );
}

sub test_atom_zero_posts {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ author_name }      = 'Test Author';

    _write_feed_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_atom_feed( $config, $tt, [] );

    open my $fh, '<', "$site->{ publication_dir }/atom.xml"
        or die "Cannot read atom.xml: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/<feed/, 'feed element present with 0 posts' );
    my @entries = $content =~ /<entry>/g;
    is( scalar @entries, 0, '0 entries in Atom feed' );

    teardown_test_site( $site );
}

sub test_atom_one_post {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ author_name }      = 'Test Author';

    _write_feed_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_atom_feed( $config, $tt, _make_posts( 1 ) );

    open my $fh, '<', "$site->{ publication_dir }/atom.xml"
        or die "Cannot read atom.xml: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my @entries = $content =~ /<entry>/g;
    is( scalar @entries, 1, '1 entry in Atom feed' );
    like( $content, qr/Post 1/, 'single post title in Atom feed' );

    teardown_test_site( $site );
}

sub test_json_multiple_posts {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_feed_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $posts = _make_posts( 3 );
    publish_json_feed( $config, $tt, $posts );

    my $file = "$site->{ publication_dir }/feed.json";
    ok( -e $file, 'feed.json created' );

    open my $fh, '<', $file or die "Cannot read $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { JSON::decode_json( $content ) };
    is( $@,        '',     'JSON feed is valid JSON' );
    is( ref $data, 'HASH', 'JSON feed root is a hash' );
    is( $data->{ version },
        'https://jsonfeed.org/version/1',
        'JSON feed version set'
    );
    is( ref $data->{ items },           'ARRAY',  'items is an array' );
    is( scalar @{ $data->{ items } },   3,        '3 items in JSON feed' );
    is( $data->{ items }[ 0 ]{ title }, 'Post 3', 'most recent post first' );

    teardown_test_site( $site );
}

sub test_json_zero_posts {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_feed_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_json_feed( $config, $tt, [] );

    open my $fh, '<', "$site->{ publication_dir }/feed.json"
        or die "Cannot read feed.json: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { JSON::decode_json( $content ) };
    is( $@, '', 'JSON feed with 0 posts is valid JSON' );
    is( scalar @{ $data->{ items } }, 0, '0 items in JSON feed' );

    teardown_test_site( $site );
}

sub test_json_one_post {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_feed_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_json_feed( $config, $tt, _make_posts( 1 ) );

    open my $fh, '<', "$site->{ publication_dir }/feed.json"
        or die "Cannot read feed.json: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { JSON::decode_json( $content ) };
    is( $@, '', 'JSON feed with 1 post is valid JSON' );
    is( scalar @{ $data->{ items } }, 1, '1 item in JSON feed' );
    is( $data->{ items }[ 0 ]{ title },
        'Post 1', 'single post title in JSON feed' );

    teardown_test_site( $site );
}

sub test_atom_cdata_escaping {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ title }            = 'My ]]> Blog';
    $config->{ author_name }      = 'Test ]]> Author';
    $config->{ author_email }     = 'test@example.com';

    _write_feed_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $posts = [
        {   title     => 'Post with ]]> in title',
            uri       => 'http://example.com/cdata-test.html',
            date      => '2024-06-01T12:00:00',
            body_html => '<p>Body with ]]> in it</p>',
        },
    ];
    publish_atom_feed( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/atom.xml"
        or die "Cannot read atom.xml: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/<\?xml/, 'feed is XML after CDATA escaping' );
    unlike( $content, qr/My \]\]> Blog/,
        'raw ]]> does not appear unescaped in feed title' );
    unlike( $content, qr/Body with \]\]> in it/,
        'raw ]]> does not appear unescaped in feed body' );

    ok( $content =~ /My \]\]\]\]><!\[CDATA\[> Blog/,
        'feed title has ]]> escaped via CDATA split' );

    my @cdata_opens  = $content =~ /<!\[CDATA\[/g;
    my @cdata_closes = $content =~ /\]\]>/g;
    is( scalar @cdata_opens, scalar @cdata_closes,
        'CDATA open/closes are balanced' );

    teardown_test_site( $site );
}

sub test_json_truncation {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ show_max_posts }   = 3;

    _write_feed_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $posts = _make_posts( 7 );
    publish_json_feed( $config, $tt, $posts );

    open my $fh, '<', "$site->{ publication_dir }/feed.json"
        or die "Cannot read feed.json: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { JSON::decode_json( $content ) };
    is( $@, '', 'Truncated JSON feed is valid JSON' );
    is( scalar @{ $data->{ items } },
        3, 'JSON feed truncated to show_max_posts items' );

    teardown_test_site( $site );
}
