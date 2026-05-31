use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Spec;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(publish_post publish_note write_meta read_all_meta);

Main();
exit;

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

    open $fh, '>', "$dir/note.tt" or die "Cannot write note.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' section_title = "Note" %]
<div>[% note.body %]</div>
[% END %]
EOF
    close $fh;
}

sub test_read_meta_one_post {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-first.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: First Post\n\nHello world.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_post( $source, $config, $tt );

    my $results = read_all_meta( $config );
    is( ref $results,     'ARRAY', 'read_all_meta returns arrayref' );
    is( scalar @$results, 1,       'one post returned' );

    my $post = $results->[ 0 ];
    is( $post->{ title }, 'First Post', 'title matches' );
    ok( defined $post->{ date }, 'date defined' );
    ok( defined $post->{ uri },  'uri defined' );
    ok( defined $post->{ id },   'id defined' );
    is( $post->{ type },      'post', 'type is post' );
    is( $post->{ body },      '',     'body is empty string' );
    is( $post->{ body_html }, '',     'body_html is empty string' );

    teardown_test_site( $site );
}

sub test_read_meta_utc_date {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y06m15d_12h00m00s-dated.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Dated Post\n\ntime: 2024-06-15T12:00:00\n\nBody.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_post( $source, $config, $tt );

    my $results = read_all_meta( $config );
    my $post    = $results->[ 0 ];

    ok( defined $post->{ utc_date }, 'utc_date defined' );
    isa_ok( $post->{ utc_date }, 'DateTime' );
    is( $post->{ year },       2024,   'year is 2024' );
    is( $post->{ month },      '06',   'month is 06' );
    is( $post->{ month_name }, 'June', 'month_name is June' );
    is( $post->{ day },        '15',   'day is 15' );

    teardown_test_site( $site );
}

sub test_read_meta_tags_expanded {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-tagged.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Tagged Post\ntags: perl, blogging\n\nBody.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_post( $source, $config, $tt );

    my $results = read_all_meta( $config );
    my $post    = $results->[ 0 ];
    my $tags    = $post->{ tags };

    is( ref $tags,     'ARRAY', 'tags is arrayref' );
    is( scalar @$tags, 2,       'two tags' );

    is( ref $tags->[ 0 ],       'HASH', 'first tag is hashref' );
    is( $tags->[ 0 ]->{ name }, 'perl', 'first tag name is perl' );
    like(
        $tags->[ 0 ]->{ uri },
        qr{/tags\.html#tag-perl-list},
        'first tag uri has tag anchor'
    );

    is( ref $tags->[ 1 ],       'HASH',     'second tag is hashref' );
    is( $tags->[ 1 ]->{ name }, 'blogging', 'second tag name is blogging' );

    teardown_test_site( $site );
}

sub test_read_meta_multiple_posts {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source1 = "$site->{ source_dir }/2024y01m15d_12h00m00s-older.md";
    open my $fh, '>', $source1 or die "Cannot write $source1: $!";
    print $fh "title: Older Post\n\nBody.\n";
    close $fh;
    publish_post( $source1, $config, $tt );

    my $source2 = "$site->{ source_dir }/2024y06m15d_12h00m00s-newer.md";
    open $fh, '>', $source2 or die "Cannot write $source2: $!";
    print $fh "title: Newer Post\n\nBody.\n";
    close $fh;
    publish_post( $source2, $config, $tt );

    my $results = read_all_meta( $config );
    is( scalar @$results,           2,            'two posts returned' );
    is( $results->[ 0 ]->{ title }, 'Newer Post', 'newest first' );
    is( $results->[ 1 ]->{ title }, 'Older Post', 'older second' );

    teardown_test_site( $site );
}

sub test_read_meta_republish {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $source = "$site->{ source_dir }/2024y02m20d_10h00m00s-repub.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Republish\n\nFirst version.\n";
    close $fh;
    publish_post( $source, $config, $tt );

    open $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Republish Updated\n\nSecond version.\n";
    close $fh;
    publish_post( $source, $config, $tt );

    my $results = read_all_meta( $config );
    is( scalar @$results, 1, 'one entry after republish' );
    is( $results->[ 0 ]->{ title },
        'Republish Updated',
        'title reflects update'
    );

    teardown_test_site( $site );
}

sub test_read_meta_empty_dir {
    my $config = test_config();
    $config->{ publication_path } = '/tmp/nonexistent_path_for_test_xxxx';

    my $results = read_all_meta( $config );
    is( ref $results,     'ARRAY', 'returns arrayref' );
    is( scalar @$results, 0,       'empty array for missing _burbleboy dir' );
}

sub test_read_meta_corrupt_file {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    mkdir $meta_dir or die "Cannot create $meta_dir: $!";

    open my $fh, '>', "$meta_dir/corrupt.meta.json"
        or die "Cannot write corrupt meta: $!";
    print $fh "this is not json";
    close $fh;

    my $results;
    {
        local $SIG{ __WARN__ } = sub { };
        $results = read_all_meta( $config );
    }
    is( ref $results,     'ARRAY', 'returns arrayref' );
    is( scalar @$results, 0,       'no valid meta files parsed' );

    teardown_test_site( $site );
}

sub test_read_meta_unicode_title {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    mkdir $meta_dir or die "Cannot create $meta_dir: $!";

    require JSON;
    my $title = "You think you\x{2019}re SO smart\x{2026}";
    my $desc  = "em-dash\x{2014}and \x{201C}smart quotes\x{201D}";

    my $meta = {
        type               => 'post',
        title              => $title,
        description        => $desc,
        date               => '2024-06-15T12:00:00',
        uri                => 'http://example.com/unicode.html',
        tags               => [],
        reading_time       => 1,
        id                 => 'unicode123',
        published_filename => 'unicode.html',
        source_file        => '/tmp/unicode.md',
    };
    write_meta( $meta, $config, 'post' );

    open my $fh, '>', "$site->{ publication_dir }/unicode.html"
        or die "Cannot write unicode.html: $!";
    print $fh "<html><body>body</body></html>";
    close $fh;

    my $results = read_all_meta( $config );
    is( scalar @$results, 1, 'one entry with unicode title returned' );
    is( $results->[ 0 ]->{ title },       $title, 'title with unicode preserved' );
    is( $results->[ 0 ]->{ description }, $desc,  'description with unicode preserved' );

    teardown_test_site( $site );
}

sub test_read_meta_orphan_skipped {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    mkdir $meta_dir or die "Cannot create $meta_dir: $!";

    require JSON;
    my $meta = {
        type               => 'post',
        title              => 'Orphan',
        date               => '2024-01-15T12:00:00',
        uri                => 'http://example.com/orphan.html',
        tags               => [],
        id                 => 'orphan123',
        published_filename => 'nonexistent.html',
        source_file        => '/tmp/nonexistent.md',
    };
    open my $fh, '>', "$meta_dir/nonexistent.html.meta.json"
        or die "Cannot write meta: $!";
    print $fh JSON::encode_json( $meta );
    close $fh;

    my $results = read_all_meta( $config );
    is( ref $results,     'ARRAY', 'returns arrayref' );
    is( scalar @$results, 0,       'orphan meta skipped' );

    teardown_test_site( $site );
}

sub test_read_meta_notes {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    mkdir $meta_dir or die "Cannot create $meta_dir: $!";

    my $note = {
        title              => 'my note title',
        date               => 1717344000,
        uri                => 'http://example.com/notes/test.html',
        tags               => [],
        id                 => 'abc123',
        published_filename => 'test-note.html',
        source_file        => '/tmp/test-note.md',
        publication_file   => '/tmp/test-note.html',
    };
    write_meta( $note, $config, 'note' );

    open my $fh, '>', "$site->{ publication_dir }/test-note.html"
        or die "Cannot write test-note.html: $!";
    print $fh "<html><body>Note body</body></html>";
    close $fh;

    my $results = read_all_meta( $config, 'note' );
    is( scalar @$results,          1,        'one note returned' );
    is( $results->[ 0 ]->{ type },  'note',          'type is note' );
    is( $results->[ 0 ]->{ id },    'abc123',        'id matches' );
    is( $results->[ 0 ]->{ body },  '',              'body is empty string' );
    is( $results->[ 0 ]->{ title }, 'my note title', 'title roundtrips' );

    ok( defined $results->[ 0 ]->{ utc_date }, 'utc_date defined for note' );
    isa_ok( $results->[ 0 ]->{ utc_date }, 'DateTime' );
    ok( defined $results->[ 0 ]->{ date_as_mysql },
        'date_as_mysql defined for note' );
    like(
        $results->[ 0 ]->{ date_as_mysql },
        qr/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/,
        'date_as_mysql formatted correctly'
    );

    teardown_test_site( $site );
}

sub test_read_meta_filter_type {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    mkdir $meta_dir or die "Cannot create $meta_dir: $!";

    require JSON;

    my $post_meta = {
        type               => 'post',
        title              => 'Filter Test Post',
        date               => '2024-06-15T12:00:00',
        uri                => 'http://example.com/filter-post.html',
        tags               => [],
        reading_time       => 1,
        id                 => 'post123',
        description        => 'A test post',
        published_filename => 'filter-post.html',
        source_file        => '/tmp/filter-post.md',
    };
    write_meta( $post_meta, $config, 'post' );

    open my $fh, '>', "$site->{ publication_dir }/filter-post.html"
        or die "Cannot write filter-post.html: $!";
    print $fh "<html><body>Post body</body></html>";
    close $fh;

    my $note = {
        date               => 1717344000,
        uri                => 'http://example.com/notes/filter-note.html',
        tags               => [],
        id                 => 'note456',
        published_filename => 'filter-note.html',
        source_file        => '/tmp/filter-note.md',
        publication_file   => '/tmp/filter-note.html',
    };
    write_meta( $note, $config, 'note' );

    open $fh, '>', "$site->{ publication_dir }/filter-note.html"
        or die "Cannot write filter-note.html: $!";
    print $fh "<html><body>Note body</body></html>";
    close $fh;

    my $all = read_all_meta( $config );
    is( scalar @$all, 2, 'both post and note returned without filter' );

    my $posts = read_all_meta( $config, 'post' );
    is( scalar @$posts,          1,      'one post with filter' );
    is( $posts->[ 0 ]->{ type }, 'post', 'filtered type is post' );

    my $notes = read_all_meta( $config, 'note' );
    is( scalar @$notes,          1,      'one note with filter' );
    is( $notes->[ 0 ]->{ type }, 'note', 'filtered type is note' );

    teardown_test_site( $site );
}

sub Main {
    test_read_meta_one_post();
    test_read_meta_utc_date();
    test_read_meta_tags_expanded();
    test_read_meta_multiple_posts();
    test_read_meta_republish();
    test_read_meta_empty_dir();
    test_read_meta_corrupt_file();
    test_read_meta_unicode_title();
    test_read_meta_orphan_skipped();
    test_read_meta_notes();
    test_read_meta_filter_type();
    test_mixed_type_date_sort();
    done_testing();
}

sub test_mixed_type_date_sort {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    mkdir $meta_dir or die "Cannot create $meta_dir: $!";

    require JSON;

    my $post_meta = {
        type               => 'post',
        title              => 'Mixed Post',
        date               => '2023-01-15T12:00:00',
        uri                => 'http://example.com/mixed-post.html',
        tags               => [],
        reading_time       => 1,
        id                 => 'post999',
        description        => 'A post',
        published_filename => 'mixed-post.html',
        source_file        => '/tmp/mixed-post.md',
    };
    write_meta( $post_meta, $config, 'post' );
    open my $fh, '>', "$site->{ publication_dir }/mixed-post.html"
        or die "Cannot write post HTML: $!";
    print $fh "<html><body>Post body</body></html>";
    close $fh;

    my $note_meta = {
        type               => 'note',
        date               => 1717344000,
        uri                => 'http://example.com/notes/mixed-note.html',
        tags               => [],
        id                 => 'note999',
        published_filename => 'mixed-note.html',
        source_file        => '/tmp/mixed-note.md',
    };
    write_meta( $note_meta, $config, 'note' );
    open $fh, '>', "$site->{ publication_dir }/mixed-note.html"
        or die "Cannot write note HTML: $!";
    print $fh "<html><body>Note body</body></html>";
    close $fh;

    my $results = read_all_meta( $config );

    ok( scalar @$results >= 2, 'at least 2 results returned' );

    my @dates = map { $_->{ date } } @$results;
    my $newer = $dates[ 0 ];
    my $older = $dates[ -1 ];
    my $sorted =
        ( $newer =~ /^\d+$/ && $older =~ /^\d+$/ )
        ? $newer > $older
        : "$newer" gt "$older";
    ok( $sorted, 'mixed post/note dates sorted newest-first' );

    teardown_test_site( $site );
}
