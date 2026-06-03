use Modern::Perl '2018';
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use Test2::V0;
use File::Temp qw(tempdir);
use Burbleboy::Publish
    qw(extract_body_from_html fill_body_for_posts fill_body_for_top_n);

Main();
exit;

sub _write_html {
    my ( $dir, $file, $content ) = @_;
    my $path = "$dir/$file";
    open my $fh, '>', $path or die "Cannot write $path: $!";
    print $fh $content;
    close $fh;
    return $path;
}

sub test_extract_body_delimiters {
    my $dir  = tempdir( CLEANUP => 1 );
    my $file = _write_html( $dir, 'test.html',
        '<html><!-- POST_BODY_START --><p>Hello</p><!-- POST_BODY_END --></html>'
    );
    my $body = extract_body_from_html( $file );
    is( $body, '<p>Hello</p>',
        'delimiters: body extracted from between comments' );
}

sub test_extract_body_nested_divs {
    my $dir  = tempdir( CLEANUP => 1 );
    my $file = _write_html( $dir, 'nested.html',
        '<html><!-- POST_BODY_START --><div><div>nested</div></div><!-- POST_BODY_END --></html>'
    );
    my $body = extract_body_from_html( $file );
    is( $body,
        '<div><div>nested</div></div>',
        'nested divs: full nested content returned'
    );
}

sub test_extract_body_no_delimiters_fallback {
    my $dir  = tempdir( CLEANUP => 1 );
    my $file = _write_html( $dir, 'legacy.html',
        '<html><div class="body e-content">body</div></html>' );
    my $body = extract_body_from_html( $file );
    is( $body, 'body', 'fallback: body extracted from e-content div' );
}

sub test_extract_body_no_matches {
    my $dir  = tempdir( CLEANUP => 1 );
    my $file = _write_html( $dir, 'nobody.html',
        '<html><p>No body markers here</p></html>' );
    my $body = extract_body_from_html( $file );
    is( $body, undef, 'no matches: returns undef' );
}

sub test_extract_body_note {
    my $dir  = tempdir( CLEANUP => 1 );
    my $file = _write_html( $dir, 'note.html',
        '<html><!-- POST_BODY_START --><p>Note body</p><!-- POST_BODY_END --></html>'
    );
    my $body = extract_body_from_html( $file );
    is( $body, '<p>Note body</p>', 'note: body extracted from note HTML' );
}

sub test_extract_body_wrapper_outside {
    my $dir  = tempdir( CLEANUP => 1 );
    my $file = _write_html( $dir, 'wrapped.html',
        '<html><div class="e-content"><!-- POST_BODY_START --><p>Clean</p><!-- POST_BODY_END --></div></html>'
    );
    my $body = extract_body_from_html( $file );
    is( $body, '<p>Clean</p>',
        'wrapper outside: body extracted without wrapper div' );
    unlike( $body, qr/e-content/,
        'wrapper outside: no template wrapper in extracted body' );
}

sub test_extract_body_file_not_found {
    my $body = extract_body_from_html( '/nonexistent/path.html' );
    is( $body, undef, 'file not found: returns undef' );
}

sub test_fill_body_for_posts {
    my $dir = tempdir( CLEANUP => 1 );
    _write_html( $dir, 'test-post.html',
        '<html><!-- POST_BODY_START --><p>Filled body</p><!-- POST_BODY_END --></html>'
    );
    my $posts = [
        {   published_filename => 'test-post.html',
            body_html          => '',
            body               => ''
        }
    ];
    fill_body_for_posts( $posts, $dir );
    is( $posts->[ 0 ]->{ body_html },
        '<p>Filled body</p>',
        'fill_body_for_posts: body_html filled'
    );
    is( $posts->[ 0 ]->{ body },
        '<p>Filled body</p>',
        'fill_body_for_posts: body filled'
    );
}

sub test_fill_body_for_top_n {
    my $dir   = tempdir( CLEANUP => 1 );
    my $posts = [];
    for my $i ( 1 .. 3 ) {
        _write_html( $dir, "post-$i.html",
            "<html><!-- POST_BODY_START --><p>Body $i</p><!-- POST_BODY_END --></html>"
        );
        push @$posts,
            {
            published_filename => "post-$i.html",
            body_html          => '',
            body               => ''
            };
    }
    fill_body_for_top_n( $posts, $dir, 2 );
    is( $posts->[ 0 ]->{ body_html },
        '<p>Body 1</p>',
        'top_n: first post filled'
    );
    is( $posts->[ 1 ]->{ body_html },
        '<p>Body 2</p>',
        'top_n: second post filled'
    );
    is( $posts->[ 2 ]->{ body_html }, '', 'top_n: third post still empty' );
}

sub test_extract_body_old_format_strips_wrapper {
    my $dir  = tempdir( CLEANUP => 1 );
    my $file = _write_html( $dir, 'old-note.html',
        '<html><!-- POST_BODY_START --><div class="e-content">Note text</div><!-- POST_BODY_END --></html>'
    );
    my $body = extract_body_from_html( $file );
    is( $body, 'Note text',
        'old format: e-content wrapper stripped from note body' );

    my $file2 = _write_html( $dir, 'old-post.html',
        '<html><!-- POST_BODY_START --><div class="body e-content"><p>Article</p></div><!-- POST_BODY_END --></html>'
    );
    my $body2 = extract_body_from_html( $file2 );
    is( $body2, '<p>Article</p>',
        'old format: body e-content wrapper stripped from post body' );
}

sub Main {
    test_extract_body_delimiters();
    test_extract_body_nested_divs();
    test_extract_body_no_delimiters_fallback();
    test_extract_body_no_matches();
    test_extract_body_note();
    test_extract_body_wrapper_outside();
    test_extract_body_file_not_found();
    test_extract_body_old_format_strips_wrapper();
    test_fill_body_for_posts();
    test_fill_body_for_top_n();
    done_testing();
}
