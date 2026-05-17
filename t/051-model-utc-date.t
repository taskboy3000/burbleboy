use Modern::Perl '2018';
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use Test2::V0;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Model::Post qw(parse_post);
use Burbleboy::Model::Note qw(parse_note);

Main();
exit;

sub Main {
    test_post_utc_date();
    test_post_utc_date_from_filename();
    test_note_utc_date();
    test_note_date_as_mysql_format();
    done_testing();
}

sub make_temp_file {
    my ( $content, $filename ) = @_;

    my $tmpdir = $FindBin::Bin . '/tmp_test_' . $$;
    mkdir $tmpdir unless -d $tmpdir;

    my $filepath = "$tmpdir/$filename";
    open my $fh, '>', $filepath or die "Cannot write $filepath: $!";
    print $fh $content;
    close $fh;

    return ( $filepath, sub { unlink $filepath; rmdir $tmpdir } );
}

sub test_post_utc_date {
    my $content = <<'EOF';
title: UTC Date Test
time: 2024-06-15T12:00:00
tags: test

Body content here.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_file( $content, '2024y01m01d_00h00m00s-utc-test.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    isa_ok( $post->{ utc_date }, 'DateTime' );
    is( $post->{ year },       2024,   'year is 2024' );
    is( $post->{ month },      '06',   'month is 06' );
    is( $post->{ month_name }, 'June', 'month_name is June' );
    is( $post->{ day },        '15',   'day is 15' );

    $cleanup->();
}

sub test_post_utc_date_from_filename {
    my $content = <<'EOF';
title: From Filename Date

Body content here.
EOF

    my ( $filepath, $cleanup ) =
        make_temp_file( $content, '2024y01m15d_12h00m00s-test.md' );
    my $config = test_config();

    my $post = parse_post( $filepath, $config );

    isa_ok( $post->{ utc_date }, 'DateTime' );
    is( $post->{ year },       2024,      'year is 2024' );
    is( $post->{ month },      '01',      'month is 01' );
    is( $post->{ month_name }, 'January', 'month_name is January' );
    is( $post->{ day },        '15',      'day is 15' );

    $cleanup->();
}

sub test_note_utc_date {
    my $content = "This is a test note.";
    my ( $filepath, $cleanup ) = make_temp_file( $content, 'utc-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    isa_ok( $note->{ utc_date }, 'DateTime' );
    like(
        $note->{ date_as_mysql },
        qr/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/,
        'date_as_mysql matches MySQL datetime format'
    );

    $cleanup->();
}

sub test_note_date_as_mysql_format {
    my $content = "Testing MySQL date format.";
    my ( $filepath, $cleanup ) =
        make_temp_file( $content, 'mysql-format-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    my $expected = $note->{ utc_date }->strftime( '%Y-%m-%d %H:%M:%S' );
    is( $note->{ date_as_mysql },
        $expected, 'date_as_mysql matches utc_date strftime' );

    $cleanup->();
}
