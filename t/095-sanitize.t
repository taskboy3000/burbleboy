use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test2::V0;

use Burbleboy::Sanitize qw(sanitize_html);

Main();
exit;

sub Main {
    test_script_tags_stripped();
    test_onclick_stripped();
    test_javascript_url_stripped();
    test_unquoted_javascript_url_stripped();
    test_normal_html_passthrough();
    test_bold_italic_links_code();
    test_onerror_stripped();
    test_event_attributes_stripped();
    test_nested_script_stripped();
    test_empty_input();
    test_no_malformed_output();
    done_testing();
}

sub test_unquoted_javascript_url_stripped {
    my $input  = '<a href=javascript:void(0)>link</a>';
    my $output = sanitize_html( $input );
    is( $output, '<a>link</a>', 'unquoted javascript: href stripped' );
}

sub test_script_tags_stripped {
    my $input  = '<p>Hello <script>alert(1)</script> world</p>';
    my $output = sanitize_html( $input );
    is( $output,
        '<p>Hello alert(1) world</p>',
        'script tags stripped, content preserved'
    );
}

sub test_onclick_stripped {
    my $input  = '<a href="http://example.com" onclick="evil()">click</a>';
    my $output = sanitize_html( $input );
    is( $output,
        '<a href="http://example.com">click</a>',
        'onclick attribute stripped'
    );
}

sub test_javascript_url_stripped {
    my $input  = '<a href="javascript:void(0)">link</a>';
    my $output = sanitize_html( $input );
    is( $output, '<a>link</a>', 'javascript: href stripped' );
}

sub test_normal_html_passthrough {
    my $input  = '<p>Hello world</p><ul><li>item</li></ul>';
    my $output = sanitize_html( $input );
    is( $output, $input, 'normal HTML preserved' );
}

sub test_bold_italic_links_code {
    my $input =
        '<p><strong>bold</strong> <em>italic</em> <a href="/">link</a> <code>code</code></p>';
    my $output = sanitize_html( $input );
    is( $output, $input, 'bold, italic, links, code preserved' );
}

sub test_onerror_stripped {
    my $input  = '<img src="x.png" onerror="alert(1)">';
    my $output = sanitize_html( $input );
    is( $output, '<img src="x.png">', 'onerror attribute stripped from img' );
}

sub test_event_attributes_stripped {
    my $input  = '<p onmouseover="evil()" onload="bad()">text</p>';
    my $output = sanitize_html( $input );
    is( $output, '<p>text</p>', 'all on* event attributes stripped' );
}

sub test_nested_script_stripped {
    my $input  = '<div><script>bad()</script><p>ok</p></div>';
    my $output = sanitize_html( $input );
    is( $output, 'bad()<p>ok</p>',
        'nested script and non-whitelist div stripped' );
}

sub test_empty_input {
    my $input  = '';
    my $output = sanitize_html( $input );
    is( $output, '', 'empty input returns empty' );
}

sub test_no_malformed_output {
    my $input  = '<p style="color:red">styled</p><div class="foo">bar</div>';
    my $output = sanitize_html( $input );
    is( $output, '<p>styled</p>bar', 'style attribute and div stripped' );
}
