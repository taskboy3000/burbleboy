use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test2::V0;

Main();
exit;

sub _slurp {
    my ( $file ) = @_;
    open my $fh, '<', $file or die "Cannot read $file: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub test_post_has_delimiters {
    my $content = _slurp( "$FindBin::Bin/../lib/Burbleboy/Template/_post.tt" );

    like $content, qr/<!-- POST_BODY_START -->/,
        '_post.tt contains POST_BODY_START comment';

    like $content, qr/<!-- POST_BODY_END -->/,
        '_post.tt contains POST_BODY_END comment';
}

sub test_note_has_delimiters {
    my $content = _slurp( "$FindBin::Bin/../lib/Burbleboy/Template/_note.tt" );

    like $content, qr/<!-- POST_BODY_START -->/,
        '_note.tt contains POST_BODY_START comment';

    like $content, qr/<!-- POST_BODY_END -->/,
        '_note.tt contains POST_BODY_END comment';
}

sub Main {
    test_post_has_delimiters();
    test_note_has_delimiters();
    done_testing();
}
