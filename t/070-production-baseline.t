use Modern::Perl '2018';
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use Test2::V0;

use Burbleboy::Model::Post qw(parse_post);

Main();
exit;

sub strip_html {
    my ( $html ) = @_;
    $html =~ s{<[^>]+>}{ }g;
    $html =~ s/\s+/ /g;
    $html =~ s/^\s+|\s+$//g;
    return $html;
}

sub normalize_quotes {
    my ( $text ) = @_;
    $text =~ s/[\x{2018}\x{2019}]/'/g;
    $text =~ s/[\x{201c}\x{201d}]/"/g;
    return $text;
}

sub test_production_post {
    my ( $label, $source_file, $expected ) = @_;

    subtest $label => sub {
        my $config = {
            publication_path => '/tmp',
            base_uri         => 'http://example.com/',
        };

        my $post = eval { parse_post( $source_file, $config ) };
        ok !$@, "parse_post succeeded"
            or diag "Error: $@";
        return unless $post;

        is $post->{ title }, $expected->{ title },
            "title: $expected->{title}";

        like $post->{ date }, qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/,
            "date is valid W3CDTF ($post->{date})";

        like $post->{ date }, $expected->{ date_year_pattern },
            "date year matches expected";

        if ( exists $expected->{ tags } ) {
            if ( defined $expected->{ tags } ) {
                is $post->{ tags }, $expected->{ tags },
                    "tags match (@{[ join ', ', @{$expected->{tags}} ]})";
            } else {
                ok !defined( $post->{ tags } ) || @{ $post->{ tags } } == 0,
                    "no tags expected";
            }
        }

        is $post->{ published_filename }, $expected->{ published_filename },
            "published_filename: $expected->{published_filename}";

        my $stripped_body = strip_html( $post->{ body_html } );
        my $normal_body   = normalize_quotes( $stripped_body );
        my $normal_snip =
            normalize_quotes( $expected->{ body_text_snippet } );
        like $normal_body, qr/\Q$normal_snip\E/,
            "body_html contains expected text snippet";

        diag "  body length: " . length( $post->{ body_html } );
    };
}

sub Main {

    test_production_post(
        '2001-04-11-Wow_  (empty tags, raw HTML body)' =>
            "$FindBin::Bin/source_model/2001-04-11-Wow_.md",
        {   title              => 'Wow!',
            date_year_pattern  => qr/^2001-/,
            tags               => undef,
            published_filename => '2001-04-11-Wow_.html',
            body_text_snippet  => 'Slash rulz',
        }
    );

    test_production_post(
        '2009-07-17-Posting_to_Twitter_using_REST_API (9 tags, raw HTML)' =>
            "$FindBin::Bin/source_model/2009-07-17-Posting_to_Twitter_using_REST_API.md",
        {   title             => 'Posting to Twitter using REST API',
            date_year_pattern => qr/^2009-/,
            tags              => [
                'HTTP', 'LWP::UserAgent', 'perl',    'programming',
                'rest', 'soap',           'twitter', 'web services',
                'xml-rpc'
            ],
            published_filename =>
                '2009-07-17-Posting_to_Twitter_using_REST_API.html',
            body_text_snippet =>
                'For a long time, I\'ve ignore the Representational State Transfer',
        }
    );

    test_production_post(
        'escape-room-roundup-2020 (Markdown body, 2 tags)' =>
            "$FindBin::Bin/source_model/escape-room-roundup-2020.md",
        {   title              => 'Escape Rooms At Home: A Personal Journey',
            date_year_pattern  => qr/^2021-/,
            tags               => [ 'games', 'escape_rooms' ],
            published_filename =>
                '2021y02m15d_16h05m34s-escape-rooms-at-home-a-personal-journey.html',
            body_text_snippet =>
                'Even before the COVID-19 lockdown, my family and I enjoyed doing escape rooms',
        }
    );

    done_testing();
}
