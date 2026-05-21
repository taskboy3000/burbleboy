use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Temp qw(tempfile);
use TestHelper qw(test_config);

use Burbleboy::Model::Note qw(parse_note);

Main();
exit;

sub Main {
    test_in_reply_to_parsing();
    test_like_of_parsing();
    test_bare_url_autolinking();
    test_bare_url_with_trailing_punctuation();
    test_hashtag_conversion();
    test_body_without_links();
    test_body_rendering();
    test_empty_body();
    test_url_validation_security();
    test_url_xss_prevention();
    done_testing();
}

sub test_url_xss_prevention {
    my $content = q{-> https://example.com/"onclick="alert(1)};
    my ( $filepath, $cleanup ) = make_temp_note( $content, 'xss-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    ok $note->{ body_html } !~ /(?<!&quot;)onclick/,
        'escaped URL does not contain unescaped event handler';
    like $note->{ body_html }, qr/&quot;onclick/,
        'double quotes in URL are HTML-escaped';

    $cleanup->();
}

sub make_temp_note {
    my ( $content, $filename ) = @_;
    $filename ||= 'test-note.txt';

    my $tmpdir = $FindBin::Bin . '/tmp_test_' . $$;
    mkdir $tmpdir unless -d $tmpdir;

    my $filepath = "$tmpdir/$filename";
    open my $fh, '>', $filepath or die "Cannot write $filepath: $!";
    print $fh $content;
    close $fh;

    return ( $filepath, sub { unlink $filepath; rmdir $tmpdir } );
}

sub test_in_reply_to_parsing {
    my $content = "->  http://facebook.com/\nThis garbage site is garbage.";
    my ( $filepath, $cleanup ) = make_temp_note( $content, 'reply-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    is( $note->{ in_reply_to },
        'http://facebook.com/',
        '-> URL sets in_reply_to'
    );
    like( $note->{ body_html }, qr/In reply to/, 'body_html has reply div' );
    like( $note->{ body_html }, qr/facebook\.com/, 'body_html has the URL' );
    like(
        $note->{ body_html },
        qr/This garbage site/,
        'body_html has remaining text'
    );

    $cleanup->();
}

sub test_like_of_parsing {
    my $content =
        "^ https://twitter.com/emilyst/status/1361086453556518912\nThis tweet is great.";
    my ( $filepath, $cleanup ) = make_temp_note( $content, 'like-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    is( $note->{ like_of },
        'https://twitter.com/emilyst/status/1361086453556518912',
        '^ URL sets like_of'
    );
    like( $note->{ body_html }, qr/like/, 'body_html has like div' );

    $cleanup->();
}

sub test_bare_url_autolinking {
    my $content = "Please see https://icanhas.cheezburger.com";
    my ( $filepath, $cleanup ) = make_temp_note( $content, 'url-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    like(
        $note->{ body_html },
        qr{<a rel="noopener noreferrer" href="https://icanhas.cheezburger.com">},
        'bare URL auto-linked'
    );

    $cleanup->();
}

sub test_bare_url_with_trailing_punctuation {
    my $content = "Check https://example.com. And https://test.com, ok?";
    my ( $filepath, $cleanup ) =
        make_temp_note( $content, 'url-punct-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    like(
        $note->{ body_html },
        qr{<a rel="noopener noreferrer" href="https://example\.com">https://example\.com</a>\.},
        'URL with trailing period has period outside anchor'
    );
    like(
        $note->{ body_html },
        qr{<a rel="noopener noreferrer" href="https://test\.com">https://test\.com</a>,},
        'URL with trailing comma has comma outside anchor'
    );

    $cleanup->();
}

sub test_hashtag_conversion {
    my $content = "I love #Perl and #Mojolicious";
    my ( $filepath, $cleanup ) =
        make_temp_note( $content, 'hashtag-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    like(
        $note->{ body_html },
        qr{<a href="tags.html#tag-perl-list">#perl</a>},
        'hashtag converted to link'
    );
    ok( grep { $_ eq 'perl' } @{ $note->{ tags } },
        'tag "perl" in tags array' );
    ok( grep { $_ eq 'mojolicious' } @{ $note->{ tags } },
        'tag "mojolicious" in tags array' );

    $cleanup->();
}

sub test_body_without_links {
    my $content = "Just a simple note.\nNothing special here.";
    my ( $filepath, $cleanup ) =
        make_temp_note( $content, 'simple-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    is( $note->{ body }, $content, 'body preserves raw text' );
    like(
        $note->{ body_html },
        qr/Just a simple note/,
        'body_html has text from first line'
    );
    like(
        $note->{ body_html },
        qr/Nothing special here/,
        'body_html has text from second line'
    );

    $cleanup->();
}

sub test_body_rendering {
    my $content = "Line one\nLine two\n\nLine four";
    my ( $filepath, $cleanup ) =
        make_temp_note( $content, 'multiline-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    like( $note->{ body_html }, qr/<br>/, 'body_html has <br> for newlines' );

    $cleanup->();
}

sub test_empty_body {
    my ( $filepath, $cleanup ) = make_temp_note( '', 'empty-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    is( $note->{ body_html },   '',    'empty body has empty body_html' );
    is( $note->{ in_reply_to }, undef, 'no in_reply_to for empty body' );
    is( $note->{ like_of },     undef, 'no like_of for empty body' );

    $cleanup->();
}

sub test_url_validation_security {
    my $content = "-> javascript:alert(1)\nThis should not be a reply.";
    my ( $filepath, $cleanup ) =
        make_temp_note( $content, 'bad-url-note.txt' );
    my $config = test_config();

    my $note = parse_note( $filepath, $config );

    is( $note->{ in_reply_to },
        undef, 'javascript: URL rejected for in_reply_to' );

    $cleanup->();
}
