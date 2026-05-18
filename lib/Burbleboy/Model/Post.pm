# Joe Johnston <jjohn@taskboy.com>, based on original work by
# Jason McIntosh <jmac@jmac.org>
package Burbleboy::Model::Post;
use Modern::Perl '2018';

use Exporter qw(import);
use File::Basename qw(basename fileparse);
use File::Spec;
use Digest::SHA qw(sha1_hex);

use Burbleboy::Markdown;

our @EXPORT_OK   = qw(parse_post);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

our $gWPM = 200;

sub parse_post {
    my ( $source_file, $config ) = @_;

    die "Source file not found: $source_file" unless -e $source_file;

    my ( $headers, $body_raw, $ordered_attrs ) = _read_source( $source_file );

    my $post = {};
    $post->{ source_file }   = $source_file;
    $post->{ body_raw }      = $body_raw;
    $post->{ attributes }    = $headers;
    $post->{ ordered_attrs } = $ordered_attrs;

    my $md        = Burbleboy::Markdown->new();
    my $body_html = $md->markdown( $body_raw || '' );
    $post->{ body_html } = _typography( $body_html );

    $post->{ title } = _parse_title( $headers, $source_file );

    $post->{ date } = _parse_date( $headers, $source_file, $config );

    $post->{ tags } = _parse_tags( $headers );

    $post->{ description } = _extract_description( $post->{ body_html } );

    $post->{ reading_time } = _calc_reading_time( $post->{ body_html } );

    $post->{ guid } = _get_or_create_guid( $headers, $source_file );

    $post->{ published_filename } = _gen_published_filename(
        $headers,
        $post->{ date },
        $post->{ title }, $source_file
    );

    $post->{ publication_file } = File::Spec->catfile(
        $config->{ publication_path }
            || $config->{ publication_directory }
            || '/tmp',
        $post->{ published_filename }
    );

    $post->{ uri } = _build_uri( $post->{ published_filename }, $config );

    $post->{ id } = sha1_hex( $post->{ uri } );

    require DateTime::Format::W3CDTF;
    my $parser = DateTime::Format::W3CDTF->new;
    my $dt     = $parser->parse_datetime( $post->{ date } );
    $dt->set_time_zone( 'UTC' );
    $post->{ utc_date }   = $dt;
    $post->{ year }       = $dt->year;
    $post->{ month }      = sprintf( '%02d', $dt->month );
    $post->{ month_name } = $dt->month_name;
    $post->{ day }        = sprintf( '%02d', $dt->day );

    return $post;
}

sub _read_source {
    my ( $filepath ) = @_;

    open my $fh, '<:encoding(UTF-8)', $filepath
        or die "Cannot read $filepath: $!";

    my %headers;
    my @ordered_attrs = qw( title time published_filename guid tags );
    my %seen_ordered;
    my $first_body_line = '';
    my $body            = '';
    my $in_body         = 0;

    while ( my $line = <$fh> ) {
        chomp $line;

        if ( !$in_body ) {
            if ( $line =~ /^\s*(\w+?)\s*:\s*(.*?)\s*$/ ) {
                my ( $key, $val ) = ( lc( $1 ), $2 );
                $headers{ $key }      = $val;
                $seen_ordered{ $key } = 1;
                unless ( grep { $_ eq $key } @ordered_attrs ) {
                    push @ordered_attrs, $key;
                }
            } else {
                $in_body         = 1;
                $first_body_line = $line;
            }
        } else {
            $body .= "$line\n";
        }
    }
    close $fh;

    if ( length( $first_body_line ) > 0 ) {
        $body = "$first_body_line\n" . $body;
    }

    return ( \%headers, $body, \@ordered_attrs );
}

sub _parse_title {
    my ( $headers, $source_file ) = @_;

    if ( exists $headers->{ title } && defined $headers->{ title } ) {
        my $title = $headers->{ title };
        $title =~ s/:/&#58;/g;
        my $md   = Burbleboy::Markdown->new();
        my $html = $md->markdown( $title );
        $html = _typography( $html );
        $html =~ s{</?(em|strong)>}{}g;
        $html =~ s{</?p>\s*}{}g;
        $html =~ s/&#58;/:/g;
        return $html;
    }

    my $base = basename( $source_file );
    $base =~ s/\.(md|markdown)$//i;
    return $base;
}

sub _parse_date {
    my ( $headers, $source_file, $config ) = @_;

    require DateTime::Format::W3CDTF;

    if ( exists $headers->{ time } && $headers->{ time } ) {
        my $parser = DateTime::Format::W3CDTF->new;
        my $dt;
        eval {
            $dt = $parser->parse_datetime( $headers->{ time } );
            $dt->set_time_zone( 'local' ) if $dt;
        };
        if ( $@ || !$dt ) {
            die
                "Error processing $source_file: The 'time' attribute is not in W3C format.\n";
        }
        return $parser->format_datetime( $dt );
    }

    my $filename = basename( $source_file );

    my ( $year, $mon, $day, $hr, $min, $sec ) =
        $filename =~ /^(\d{4})y(\d{2})m(\d{2})d_(\d{2})h(\d{2})m(\d{2})s/;

    if ( $year ) {
        require DateTime;
        my $dt = DateTime->new(
            year      => $year,
            month     => $mon,
            day       => $day,
            hour      => $hr,
            minute    => $min,
            second    => $sec,
            time_zone => 'local',
        );
        my $parser = DateTime::Format::W3CDTF->new;
        $headers->{ time } = $parser->format_datetime( $dt );
        return $headers->{ time };
    }

    ( $year, $mon, $day ) = $filename =~ /^(\d{4})-(\d{2})-(\d{2})-/;
    if ( $year ) {
        require DateTime;
        my $now = DateTime->now( time_zone => 'local' );
        my $dt  = DateTime->new(
            year      => $year,
            month     => $mon,
            day       => $day,
            hour      => $now->hour,
            minute    => $now->minute,
            second    => $now->second,
            time_zone => 'local',
        );
        my $parser = DateTime::Format::W3CDTF->new;
        $headers->{ time } = $parser->format_datetime( $dt );
        return $headers->{ time };
    }

    my @stat = stat( $source_file );
    require DateTime;
    my $dt =
        DateTime->from_epoch( epoch => $stat[ 9 ], time_zone => 'local' );
    require DateTime::Format::W3CDTF;
    my $parser = DateTime::Format::W3CDTF->new;
    $headers->{ time } = $parser->format_datetime( $dt );
    return $headers->{ time };
}

sub _parse_tags {
    my ( $headers ) = @_;

    return undef
        unless exists $headers->{ tags } && defined $headers->{ tags };

    my $tags_str = $headers->{ tags };
    return undef unless $tags_str;

    my @tags = split /\s*,\s*/, $tags_str;

    @tags = grep { defined $_ && length( $_ ) > 0 } @tags;

    return undef unless @tags;

    return \@tags;
}

sub _extract_description {
    my ( $body_html ) = @_;

    return '' unless $body_html;

    my $stripped = $body_html;
    $stripped =~ s{<[^>]+>}{ }g;
    $stripped =~ s/\s+/ /g;
    $stripped =~ s/^\s+//;
    $stripped =~ s/\s+$//;

    my ( $first_sentence ) = $stripped =~ /^(.+?)(?:[\.\!\?]|$)/;
    $first_sentence //= $stripped;

    return $first_sentence;
}

sub _calc_reading_time {
    my ( $body_html ) = @_;

    return 0 unless $body_html;

    my $stripped = $body_html;
    $stripped =~ s{<[^>]+>}{ }g;
    my @words = $stripped =~ /(\w+)\W*/g;

    return 0 unless @words;

    return int( ( scalar( @words ) + $gWPM - 1 ) / $gWPM );
}

sub _get_or_create_guid {
    my ( $headers, $source_file ) = @_;

    if ( exists $headers->{ guid } && $headers->{ guid } ) {
        return $headers->{ guid };
    }

    $headers->{ guid } = sha1_hex( $source_file );
    return $headers->{ guid };
}

sub _gen_published_filename {
    my ( $headers, $date, $title, $source_file ) = @_;

    if ( $headers->{ published_filename } ) {
        my $name = $headers->{ published_filename };
        $name =~ s/[<>&"']/_/g;
        $name =~ s/[[:cntrl:]]//g;
        return $name;
    }

    my $filename = basename( $source_file );

    if ( $filename =~ /^\d{4}y\d{2}m\d{2}d_\d{2}h\d{2}m\d{2}s-/ ) {
        $filename =~ s/\..*$/.html/;
        $filename =~ s/[<>&"']/_/g;
        $filename =~ s/[[:cntrl:]]//g;
        return $filename;
    }

    my $clean_title = lc( $title || 'untitled' );
    $clean_title =~ s/\s+/-/g;
    $clean_title =~ s/--+/-/g;
    $clean_title =~ s/[^A-Z0-9\-]+//ig;
    $clean_title =~ s/^-+//;
    $clean_title =~ s/-+$//;
    $clean_title ||= 'untitled';

    my ( $year, $mon, $day, $hr, $min, $sec );

    # Trailing timezone (e.g. +00:00, -05:00, Z) is intentionally ignored;
    # the six captured fields are sufficient for filename generation.
    if ( $date =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/ ) {
        ( $year, $mon, $day, $hr, $min, $sec ) = ( $1, $2, $3, $4, $5, $6 );
    } else {
        require DateTime;
        my $now = DateTime->now( time_zone => 'local' );
        $year = $now->year;
        $mon  = $now->month;
        $day  = $now->day;
        $hr   = $now->hour;
        $min  = $now->minute;
        $sec  = $now->second;
    }

    $filename = sprintf( "%04dy%02dm%02dd_%02dh%02dm%02ds-%s.html",
        $year, $mon, $day, $hr, $min, $sec, $clean_title );

    $headers->{ published_filename } = $filename;
    return $filename;
}

sub _build_uri {
    my ( $published_filename, $config ) = @_;

    my $base_uri = $config->{ base_uri } || 'http://localhost/';
    if ( $base_uri =~ /[^\/]$/ ) {
        $base_uri .= '/';
    }

    my $path = $published_filename;
    $path =~ s/[<>&"']/_/g;
    $path =~ s/[[:cntrl:]]//g;

    return $base_uri . $path;
}

sub _typography {
    my ( $text ) = @_;
    return '' unless defined $text;
    $text =~ s/\x{201c}/"/g;
    $text =~ s/\x{201d}/"/g;
    $text =~ s/\x{2018}/'/g;
    $text =~ s/\x{2019}/'/g;
    $text =~ s/---/\x{2014}/g;
    $text =~ s/--/\x{2013}/g;
    $text =~ s/\.\.\./\x{2026}/g;
    return $text;
}

1;
