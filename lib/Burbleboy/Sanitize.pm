package Burbleboy::Sanitize;
use Modern::Perl '2018';

use Exporter qw(import);
our @EXPORT_OK   = qw(sanitize_html);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

my @WHITELIST_TAGS = qw(
    p a img ul ol li blockquote pre code em strong
    h1 h2 h3 h4 h5 h6 br hr table tr td th
);
my $WHITELIST_PAT = join '|', @WHITELIST_TAGS;

sub sanitize_html {
    my ( $html ) = @_;
    return '' unless defined $html;

    $html =~ s{\s+on\w+\s*=\s*(?:"[^"]*"|'[^']*'|\S+)}{}gi;

    $html =~
        s{\s+(?:href|src)\s*=\s*(?:"(?:javascript|data):[^"]*"|'(?:javascript|data):[^']*'|(?:javascript|data):[^\s>]+)}{}gi;

    $html =~ s{<(?!\/?(?:$WHITELIST_PAT)\b)[^>]*>}{}g;

    $html =~ s{<(/?)($WHITELIST_PAT)([^>]*)>}{_safe_tag($1, $2, $3)}gie;

    return $html;
}

sub _safe_tag {
    my ( $close, $tag, $attrs ) = @_;

    return "<$close$tag>" if $close;
    return "<$tag>"       if $tag =~ /^(?:br|hr)$/;

    my $safe = '';
    while ( $attrs =~ m{(\w+)\s*=\s*(?:"([^"]*)"|'([^']*)'|(\S+))}g ) {
        my ( $name, $val ) = ( $1, $2 // $3 // $4 );
        next unless $name =~ /^(?:href|src|alt|title|rel|class|id)$/;
        $safe .= qq{ $name="$val"} if length $val;
    }

    return "<$tag$safe>";
}

1;
