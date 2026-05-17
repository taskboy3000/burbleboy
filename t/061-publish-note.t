use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Spec;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(publish_note);

Main();
exit;

sub Main {
    test_fresh_note();
    test_note_body_rendering();
    test_note_filename();
    test_emoji_in_note();
    test_note_in_reply_to();
    test_note_like_of();
    test_empty_body_note();
    done_testing();
}

sub _write_minimal_templates {
    my ( $dir ) = @_;

    open my $fh, '>', "$dir/layout.tt" or die "Cannot write layout.tt: $!";
    print $fh <<'EOF';
<!DOCTYPE html>
<html>
<head><title>[% config.title %] :: [% section_title | html %]</title></head>
<body>
[% content %]
</body>
</html>
EOF
    close $fh;

    open $fh, '>', "$dir/note.tt" or die "Cannot write note.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' section_title = "Note" %]
<div class="note">
[% IF note.body_html %]<div class="body">[% note.body_html %]</div>[% END %]
[% IF note.in_reply_to %]<div class="in-reply-to">In reply to: <a href="[% note.in_reply_to %]">[% note.in_reply_to %]</a></div>[% END %]
[% IF note.like_of %]<div class="like-of">Like: <a href="[% note.like_of %]">[% note.like_of %]</a></div>[% END %]
</div>
[% END %]
EOF
    close $fh;
}

sub test_fresh_note {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-fresh-note.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "Hello from a fresh note.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $note = publish_note( $source, $config, $tt );

    ok( -e $note->{ publication_file },
        'output file created on fresh note publish' );

    open $fh, '<', $note->{ publication_file } or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like(
        $content,
        qr/Hello from a fresh note/,
        'note body appears in output'
    );

    teardown_test_site( $site );
}

sub test_note_body_rendering {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y02m10d_08h30m00s-body-note.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "First line\nSecond line\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $note = publish_note( $source, $config, $tt );

    open $fh, '<', $note->{ publication_file } or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/First line/,  'first line appears in output' );
    like( $content, qr/Second line/, 'second line appears in output' );

    teardown_test_site( $site );
}

sub test_note_filename {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y03m20d_14h15m00s-custom-name.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "Note with custom name.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $note = publish_note( $source, $config, $tt );

    like( $note->{ publication_file },
        qr/\.html$/, 'publication_file ends with .html' );
    ok( -e $note->{ publication_file },
        'output file exists at publication_file path' );

    teardown_test_site( $site );
}

sub test_emoji_in_note {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/emoji-note.md";
    open my $fh, '>:utf8', $source or die "Cannot write $source: $!";
    print $fh "Note with emoji \x{1F3C6}\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $warnings = '';
    local $SIG{ __WARN__ } = sub { $warnings .= shift };

    my $note = publish_note( $source, $config, $tt );

    is( $warnings, '', 'no warnings during publish_note with emoji' );

    ok( -e $note->{ publication_file },
        'output file created for emoji note' );

    open $fh, '<:encoding(UTF-8)', $note->{ publication_file } or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/Note with emoji/,
        'note body contains emoji label' );
    like( $content, qr/\x{1F3C6}/,
        'note output contains emoji character' );

    teardown_test_site( $site );
}

sub test_note_in_reply_to {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y04m05d_09h00m00s-reply-note.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "-> https://example.com/original\nMy reply.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $note = publish_note( $source, $config, $tt );

    open $fh, '<', $note->{ publication_file } or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/In reply to/,  'in-reply-to text appears in output' );
    like( $content, qr/example\.com/, 'reply URL appears in output' );
    like( $content, qr/\bMy reply\b/, 'reply body appears in output' );

    teardown_test_site( $site );
}

sub test_note_like_of {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y05m10d_11h00m00s-like-note.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "^ https://example.com/great-post\nLiked this.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $note = publish_note( $source, $config, $tt );

    open $fh, '<', $note->{ publication_file } or die;
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/\bLike\b/,       'like-of text appears in output' );
    like( $content, qr/example\.com/,   'like URL appears in output' );
    like( $content, qr/\bLiked this\b/, 'like body appears in output' );

    teardown_test_site( $site );
}

sub test_empty_body_note {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y06m01d_00h00m00s-empty.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $note = publish_note( $source, $config, $tt );

    ok( -e $note->{ publication_file },
        'output file created for empty body note' );

    teardown_test_site( $site );
}
