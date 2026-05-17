use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Temp qw(tempfile);
use File::Spec;
use TestHelper qw(test_config);

use Burbleboy::Model::Post qw(parse_post);

Main();
exit;

sub Main {
    test_header_parsing();
    test_markdown_body();
    test_old_format_filename();
    test_new_format_filename();
    test_missing_time_attribute();
    test_time_attribute();
    test_tag_parsing();
    test_no_tags();
    test_description_extraction();
    test_reading_time();
    test_reading_time_edge_cases();
    test_published_filename();
    test_bad_date_format();
    test_guid_and_extra_keys();
    done_testing();
}

sub make_temp_post {
    my ( $content, $filename ) = @_;
    $filename ||= 'test-post.md';

    my $tmpdir = $FindBin::Bin . '/tmp_test_' . $$;
    mkdir $tmpdir unless -d $tmpdir;

    my $filepath = "$tmpdir/$filename";
    open my $fh, '>', $filepath or die "Cannot write $filepath: $!";
    print $fh $content;
    close $fh;

    return ( $filepath, sub { unlink $filepath; rmdir $tmpdir } );
}

sub test_header_parsing {
    my $content = <<'EOF';
title: Test Post Title
tags: foo, bar

Body content here.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-test.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    is( $post->{ title }, 'Test Post Title', 'title parsed correctly' );
    ok( $post->{ body_html }, 'body has HTML' );
    like( $post->{ body_raw }, qr/Body content here/, 'body_raw preserved' );

    $cleanup->();
}

sub test_markdown_body {
    my $content = <<'EOF';
title: Markdown Test

This is **bold** and *italic*.

- List item 1
- List item 2
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-markdown.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    like( $post->{ body_html }, qr/<strong>bold<\/strong>/, 'bold rendered' );
    like( $post->{ body_html }, qr/<em>italic<\/em>/, 'italic rendered' );
    like( $post->{ body_html }, qr/<li>/,             'list items rendered' );

    $cleanup->();
}

sub test_old_format_filename {
    my $content = <<'EOF';
title: Old Format

Old style filename without embedded time.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020-01-15-My-Slug.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    is( $post->{ title }, 'Old Format', 'title from old format file' );
    ok( $post->{ date },      'date extracted/set' );
    ok( $post->{ body_html }, 'body rendered' );

    $cleanup->();
}

sub test_new_format_filename {
    my $content = <<'EOF';
title: New Format

New style filename with embedded timestamp.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_14h30m00s-new-slug.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    is( $post->{ title }, 'New Format', 'title from new format file' );
    like( $post->{ date }, qr/2020/, 'year from filename' );
    ok( $post->{ body_html }, 'body rendered' );

    $cleanup->();
}

sub test_missing_time_attribute {
    my $content = <<'EOF';
title: No Time Header

This post has no time: attribute in headers.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2021y05m20d_10h11m12s-no-time.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    ok( $post->{ date },
        'date set from filename when missing time attribute' );
    like( $post->{ date }, qr/2021-05-20/, 'date uses filename values' );

    $cleanup->();
}

sub test_time_attribute {
    my $content = <<'EOF';
title: Has Time
time: 2022-06-15T13:45:30-04:00

Time from header should be used.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '1999y01m01d_00h00m00s-ignore-this.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    like( $post->{ date },
        qr/2022-06-15/, 'time attribute overrides filename' );
    like( $post->{ date }, qr/13:45:30/, 'time preserved' );

    $cleanup->();
}

sub test_tag_parsing {
    my $content = <<'EOF';
title: Tags Test
tags: Perl, Mojolicious, Web Development

Testing tag parsing.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-tags.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    is( ref $post->{ tags },         'ARRAY', 'tags is arrayref' );
    is( scalar @{ $post->{ tags } }, 3,       'three tags parsed' );

    $cleanup->();
}

sub test_no_tags {
    my $content = <<'EOF';
title: No Tags Here

No tags attribute in this post.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-notags.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    is( $post->{ tags }, undef, 'no tags = undef or empty' );

    $cleanup->();
}

sub test_description_extraction {
    my $content = <<'EOF';
title: Description Test

First paragraph should be the description.

Second paragraph should not matter.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-desc.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    like(
        $post->{ description },
        qr/First paragraph/,
        'description extracted from first para'
    );
    unlike(
        $post->{ description },
        qr/Second paragraph/,
        'second para not in description'
    );

    $cleanup->();
}

sub test_reading_time {
    my @words = ( 'word' ) x 600;
    my $body  = join( ' ', @words );

    my $content = <<"EOF";
title: Reading Time Test

$body
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-reading.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    is( $post->{ reading_time }, 3, '600 words at 200 WPM = 3 minutes' );

    $cleanup->();
}

sub test_reading_time_edge_cases {
    my $config = test_config();

    my @two_hundred = ( 'word' ) x 200;
    my $body200     = join( ' ', @two_hundred );
    my $content     = <<"EOF";
title: 200 Words

$body200
EOF
    my ( $fp200, $cleanup200 ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-200.md' );
    my $post200 = parse_post( $fp200, $config );
    is( $post200->{ reading_time }, 1, '200 words at 200 WPM = 1 minute' );
    $cleanup200->();

    my @two_o_one = ( 'word' ) x 201;
    my $body201   = join( ' ', @two_o_one );
    $content = <<"EOF";
title: 201 Words

$body201
EOF
    my ( $fp201, $cleanup201 ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-201.md' );
    my $post201 = parse_post( $fp201, $config );
    is( $post201->{ reading_time }, 2, '201 words at 200 WPM = 2 minutes' );
    $cleanup201->();

    my ( $fp0, $cleanup0 ) =
        make_temp_post( "title: Empty\n\n", '2020y01m15d_12h00m00s-0.md' );
    my $post0 = parse_post( $fp0, $config );
    is( $post0->{ reading_time }, 0, 'empty body = 0 minutes' );
    $cleanup0->();
}

sub test_published_filename {
    my $content = <<'EOF';
title: Published Filename

Testing published filename generation.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2023y07m04d_09h08m07s-my-test-post.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    like(
        $post->{ published_filename },
        qr/2023y07m04d_09h08m07s-.*\.html$/,
        'published filename uses timestamp'
    );
    like(
        $post->{ publication_file },
        qr/\Q$post->{published_filename}\E$/,
        'publication_file ends with published_filename'
    );

    $cleanup->();
}

sub test_bad_date_format {
    my $content = <<'EOF';
title: Bad Date
time: um, three?

This file has an invalid time format.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-bad.md' );
    my $config = test_config();

    like(
        dies { parse_post( $filepath, $config ) },
        qr/(time|format|date|invalid)/i,
        'bad time format dies with error'
    );

    $cleanup->();
}

sub test_guid_and_extra_keys {
    my $content = <<'EOF';
title: GUID and extras
guid: test-guid-12345

Has a pre-existing GUID.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_post( $content, '2020y01m15d_12h00m00s-guid.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    is( $post->{ guid },
        'test-guid-12345', 'existing GUID preserved from headers' );
    ok( $post->{ uri }, 'uri generated' );
    like( $post->{ uri }, qr/\.html$/, 'uri ends in html' );

    $cleanup->();
}
