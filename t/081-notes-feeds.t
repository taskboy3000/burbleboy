use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Spec;
use Template;
use JSON;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(publish_notes_roll publish_notes_json);

Main();
exit;

sub Main {
    test_notes_roll_with_notes();
    test_notes_roll_zero_notes();
    test_notes_roll_one_note();
    test_notes_json_with_notes();
    test_notes_json_zero_notes();
    test_notes_json_one_note();
    test_notes_json_truncation();
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

    open $fh, '>', "$dir/notes_roll.tt"
        or die "Cannot write notes_roll.tt: $!";
    print $fh <<'END_TMPL';
[% IF notes.size > 0 -%]
  [% FOREACH note = notes %]
    <div class="note">
      <div class="body">[% note.body_html %]</div>
      <div class="uri"><a href="[% note.uri %]">permalink</a></div>
    </div>
  [% END %]
[% ELSE %]
  <em>No notes posted yet.</em>
[% END %]
END_TMPL
    close $fh;
}

sub _make_notes {
    my ( $count ) = @_;
    my @notes;
    for my $i ( 1 .. $count ) {
        my $ts = 1704067200 + ( $i * 3600 );    # 2024-01-01 + i hours
        push @notes,
            {
            body      => "Note $i body",
            body_html => "Note $i body",
            date      => $ts,
            uri       => "http://example.com/notes/note-$i.html",
            id        => "id-$i",
            };
    }
    return \@notes;
}

sub test_notes_roll_with_notes {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    my $notes = _make_notes( 3 );
    publish_notes_roll( $config, $tt, $notes );

    my $file = "$site->{ publication_dir }/notes.html";
    ok( -e $file, 'notes.html created' );

    open my $fh, '<', $file or die "Cannot read $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/Note 1 body/, 'first note body appears' );
    like( $content, qr/Note 3 body/, 'last note body appears' );
    like( $content, qr/permalink/,   'permalink link present in roll' );

    teardown_test_site( $site );
}

sub test_notes_roll_zero_notes {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_notes_roll( $config, $tt, [] );

    open my $fh, '<', "$site->{ publication_dir }/notes.html"
        or die "Cannot read notes.html: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/No notes posted/, 'empty state message when 0 notes' );

    teardown_test_site( $site );
}

sub test_notes_roll_one_note {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_notes_roll( $config, $tt, _make_notes( 1 ) );

    open my $fh, '<', "$site->{ publication_dir }/notes.html"
        or die "Cannot read notes.html: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/Note 1 body/, 'single note body appears' );

    teardown_test_site( $site );
}

sub test_notes_json_with_notes {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $tt = Template->new();

    my $notes = _make_notes( 3 );
    publish_notes_json( $config, $tt, $notes );

    my $file = "$site->{ publication_dir }/recent_notes.json";
    ok( -e $file, 'recent_notes.json created' );

    open my $fh, '<', $file or die "Cannot read $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { JSON::decode_json( $content ) };
    is( $@,        '',     'notes JSON feed is valid JSON' );
    is( ref $data, 'HASH', 'notes JSON feed root is a hash' );
    is( $data->{ version },
        'https://jsonfeed.org/version/1',
        'JSON feed version set'
    );
    is( ref $data->{ items },         'ARRAY', 'items is an array' );
    is( scalar @{ $data->{ items } }, 3,       '3 items in notes JSON feed' );

    teardown_test_site( $site );
}

sub test_notes_json_zero_notes {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $tt = Template->new();

    publish_notes_json( $config, $tt, [] );

    open my $fh, '<', "$site->{ publication_dir }/recent_notes.json"
        or die "Cannot read recent_notes.json: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { JSON::decode_json( $content ) };
    is( $@, '', 'notes JSON feed with 0 notes is valid JSON' );
    is( scalar @{ $data->{ items } }, 0, '0 items in notes JSON feed' );

    teardown_test_site( $site );
}

sub test_notes_json_one_note {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $tt = Template->new();

    publish_notes_json( $config, $tt, _make_notes( 1 ) );

    open my $fh, '<', "$site->{ publication_dir }/recent_notes.json"
        or die "Cannot read recent_notes.json: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { JSON::decode_json( $content ) };
    is( $@, '', 'notes JSON feed with 1 note is valid JSON' );
    is( scalar @{ $data->{ items } }, 1, '1 item in notes JSON feed' );

    teardown_test_site( $site );
}

sub test_notes_json_truncation {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };
    $config->{ show_max_posts }   = 3;

    my $tt = Template->new();

    my $notes = _make_notes( 7 );
    publish_notes_json( $config, $tt, $notes );

    open my $fh, '<', "$site->{ publication_dir }/recent_notes.json"
        or die "Cannot read recent_notes.json: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { JSON::decode_json( $content ) };
    is( $@, '', 'Truncated notes JSON feed is valid JSON' );
    is( scalar @{ $data->{ items } },
        3, 'notes JSON feed truncated to show_max_posts items' );

    teardown_test_site( $site );
}
