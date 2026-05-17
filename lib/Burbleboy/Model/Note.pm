# Joe Johnston <jjohn@taskboy.com>
package Burbleboy::Model::Note;
use Modern::Perl '2018';

use Exporter qw(import);
use File::Basename qw(basename);
use File::Spec;
use Digest::SHA qw(sha1_hex);

our @EXPORT_OK   = qw(parse_note);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub parse_note {
    my ( $source_file, $config ) = @_;

    die "Source file not found: $source_file" unless -e $source_file;

    open my $fh, '<:encoding(UTF-8)', $source_file or die "Cannot read $source_file: $!";
    my $raw_body = do { local $/; <$fh> };
    close $fh;

    my $note = {};
    $note->{ body }     = $raw_body;
    $note->{ body_raw } = $raw_body;

    my $url_pat = q{https?://\S+};

    my @lines = split /\r?\n/, ( $raw_body || '' );
    my @body_lines;
    my ( $in_reply_to, $like_of );
    my @tags;

    for my $line ( @lines ) {
        if ( $line =~ /^->\s*($url_pat)$/ ) {
            $in_reply_to = _validate_url( $1 );
            if ( $in_reply_to ) {
                $in_reply_to = _escape_html( $in_reply_to );
                push @body_lines,
                    sprintf(
                    '<div class="h-cite u-in-reply-to reply-to">In reply to: <a rel="noopener noreferrer" href="%s">%s</a></div>',
                    $in_reply_to, $in_reply_to );
            } else {
                push @body_lines, $line;
            }
            next;
        }

        if ( $line =~ /^\^\s*($url_pat)$/ ) {
            $like_of = _validate_url( $1 );
            if ( $like_of ) {
                $like_of = _escape_html( $like_of );
                push @body_lines,
                    sprintf(
                    '<div class="h-cite u-like-of like">&#x1F44D; <a rel="noopener noreferrer" class="" href="%s">%s</a></div>',
                    $like_of, $like_of );
            } else {
                push @body_lines, $line;
            }
            next;
        }

        my @words;
        for my $word ( split / /, $line ) {
            if ( $word =~ m!($url_pat)!o ) {
                my $url = _validate_url( $1 );
                if ( $url ) {
                    $url  = _escape_html( $url );
                    $word = sprintf(
                        '<a rel="noopener noreferrer" href="%s">%s</a>',
                        $url, $url );
                }
            } elsif ( $word =~ /^#([\w-]+)/ ) {
                my $tag = lc( $1 );
                $tag =~ s/[^a-z0-9-]//g;
                push @tags, $tag if $tag;
                if ( $tag ) {
                    $word =
                        sprintf( '<a href="tags.html#tag-%s-list">#%s</a>',
                        $tag, $tag );
                }
            }
            push @words, $word;
        }
        push @body_lines, join( ' ', @words );
    }

    $note->{ body_html } = join( "<br>\n", @body_lines );

    $note->{ in_reply_to } = $in_reply_to;
    $note->{ like_of }     = $like_of;

    $note->{ tags } = \@tags;

    my @stat = stat( $source_file );
    $note->{ date } = $stat[ 9 ];

    my $base = basename( $source_file );
    $base =~ s/\.[^.]+$//;
    my $pub_dir =
           $config->{ publication_path }
        || $config->{ publication_directory }
        || '/tmp';
    $note->{ publication_file } =
        File::Spec->catfile( $pub_dir, 'notes', $base . '.html' );
    $note->{ published_filename } = 'notes/' . $base . '.html';
    $note->{ source_file }        = $source_file;

    my $base_uri = $config->{ base_uri } || 'http://localhost/';
    $base_uri =~ s{/$}{};
    $note->{ uri } = $base_uri . '/notes/' . $base . '.html';

    $note->{ id } = sha1_hex( $note->{ uri } );

    require DateTime;
    my $dt =
        DateTime->from_epoch( epoch => $note->{ date }, time_zone => 'UTC' );
    $note->{ utc_date }      = $dt;
    $note->{ date_as_mysql } = $dt->strftime( '%Y-%m-%d %H:%M:%S' );

    return $note;
}

sub _escape_html {
    my ( $s ) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&#39;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    return $s;
}

sub _validate_url {
    my ( $url ) = @_;
    return unless defined $url;
    return $url if $url =~ /^https?:\/\//i;
    return;
}

1;
