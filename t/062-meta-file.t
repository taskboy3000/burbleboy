use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Spec;
use Template;
use TestHelper qw(setup_test_site teardown_test_site test_config);

use Burbleboy::Publish qw(publish_post publish_note write_meta);

Main();
exit;

sub _write_minimal_templates {
    my ( $dir ) = @_;

    open my $fh, '>', "$dir/layout.tt" or die "Cannot write layout.tt: $!";
    print $fh <<'EOF';
<!DOCTYPE html>
<html lang="en">
<head><title>[% config.title %] :: [% section_title | html %]</title></head>
<body>
[% content %]
</body>
</html>
EOF
    close $fh;

    open $fh, '>', "$dir/single_post.tt"
        or die "Cannot write single_post.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' section_title = post.title %]
<article>
<h1>[% post.title %]</h1>
<div>[% post.body %]</div>
</article>
[% END %]
EOF
    close $fh;

    open $fh, '>', "$dir/note.tt" or die "Cannot write note.tt: $!";
    print $fh <<'EOF';
[% WRAPPER 'layout.tt' section_title = "Note" %]
<div>[% note.body %]</div>
[% END %]
EOF
    close $fh;
}

sub test_meta_file_created {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-fresh.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Fresh Post\n\nHello world.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_post( $source, $config, $tt );

    my $meta_file =
        "$site->{ publication_dir }/_burbleboy/2024y01m15d_12h00m00s-fresh.html.meta.json";
    ok( -e $meta_file, 'meta file created for post' );

    teardown_test_site( $site );
}

sub test_meta_file_content {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-fresh.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Fresh Post\n\nHello world.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_post( $source, $config, $tt );

    my $meta_file =
        "$site->{ publication_dir }/_burbleboy/2024y01m15d_12h00m00s-fresh.html.meta.json";
    open $fh, '<', $meta_file or die "Cannot read $meta_file: $!";
    my $json = do { local $/; <$fh> };
    close $fh;

    require JSON;
    my $meta = JSON::decode_json( $json );

    is( $meta->{ title }, 'Fresh Post', 'meta title matches' );
    is( $meta->{ type },  'post',       'meta type is post' );
    ok( defined $meta->{ uri }, 'meta uri is defined' );
    like(
        $meta->{ date },
        qr/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/,
        'meta date is W3CDTF'
    );
    like( $meta->{ id }, qr/^[0-9a-f]{40}$/, 'meta id is sha1 hex' );

    teardown_test_site( $site );
}

sub test_meta_file_no_body {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-fresh.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Fresh Post\n\nHello world.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_post( $source, $config, $tt );

    my $meta_file =
        "$site->{ publication_dir }/_burbleboy/2024y01m15d_12h00m00s-fresh.html.meta.json";
    open $fh, '<', $meta_file or die "Cannot read $meta_file: $!";
    my $json = do { local $/; <$fh> };
    close $fh;

    require JSON;
    my $meta = JSON::decode_json( $json );

    ok( !exists $meta->{ body_html }, 'no body_html in meta' );
    ok( !exists $meta->{ body },      'no body in meta' );

    teardown_test_site( $site );
}

sub test_meta_file_republish {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y02m20d_10h00m00s-repub.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Republish\n\nFirst version.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_post( $source, $config, $tt );

    open $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Republish Updated\n\nSecond version.\n";
    close $fh;

    publish_post( $source, $config, $tt );

    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    opendir my $dh, $meta_dir or die "Cannot read $meta_dir: $!";
    my @meta_files = grep { /\.meta\.json$/ } readdir( $dh );
    closedir $dh;

    is( scalar @meta_files, 1, 'only one meta file after republish' );

    my $meta_file = "$meta_dir/2024y02m20d_10h00m00s-repub.html.meta.json";
    open $fh, '<', $meta_file or die "Cannot read $meta_file: $!";
    my $json = do { local $/; <$fh> };
    close $fh;

    require JSON;
    my $meta = JSON::decode_json( $json );
    is( $meta->{ title },
        'Republish Updated',
        'meta title reflects republish update'
    );

    teardown_test_site( $site );
}

sub test_meta_note_created {
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

    publish_note( $source, $config, $tt );

    my $meta_file =
        "$site->{ publication_dir }/_burbleboy/notes/2024y01m15d_12h00m00s-fresh-note.html.meta.json";
    ok( -e $meta_file, 'meta file created for note' );

    teardown_test_site( $site );
}

sub test_meta_note_fields {
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

    publish_note( $source, $config, $tt );

    my $meta_file =
        "$site->{ publication_dir }/_burbleboy/notes/2024y01m15d_12h00m00s-fresh-note.html.meta.json";
    open $fh, '<', $meta_file or die "Cannot read $meta_file: $!";
    my $json = do { local $/; <$fh> };
    close $fh;

    require JSON;
    my $meta = JSON::decode_json( $json );

    is( $meta->{ type }, 'note', 'note meta type is note' );
    ok( defined $meta->{ published_filename },
        'note meta published_filename defined'
    );
    ok( defined $meta->{ date },  'note meta date defined' );
    ok( defined $meta->{ title }, 'note meta title defined' );
    is( $meta->{ title },
        'fresh note',
        'note meta title from filename (datestamp stripped, underscores/dashes -> spaces)'
    );

    teardown_test_site( $site );
}

sub test_meta_atomic_write {
    my $site   = setup_test_site();
    my $config = test_config();
    $config->{ publication_path } = $site->{ publication_dir };

    my $source = "$site->{ source_dir }/2024y01m15d_12h00m00s-fresh.md";
    open my $fh, '>', $source or die "Cannot write $source: $!";
    print $fh "title: Fresh Post\n\nHello world.\n";
    close $fh;

    _write_minimal_templates( $site->{ tmpdir } );

    my $tt = Template->new(
        {   INCLUDE_PATH => $site->{ tmpdir },
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        }
    );

    publish_post( $source, $config, $tt );

    my $meta_dir = "$site->{ publication_dir }/_burbleboy";
    opendir my $dh, $meta_dir or die "Cannot read $meta_dir: $!";
    my @tmp_files = grep { /\.tmp$/ } readdir( $dh );
    closedir $dh;

    is( scalar @tmp_files, 0, 'no .tmp files remain after write_meta' );

    my $meta_file = "$meta_dir/2024y01m15d_12h00m00s-fresh.html.meta.json";
    open $fh, '<', $meta_file or die "Cannot read $meta_file: $!";
    my $json = do { local $/; <$fh> };
    close $fh;

    require JSON;
    my $meta = eval { JSON::decode_json( $json ) };
    ok( defined $meta, 'meta file is valid JSON' );

    teardown_test_site( $site );
}

sub Main {
    test_meta_file_created();
    test_meta_file_content();
    test_meta_file_no_body();
    test_meta_file_republish();
    test_meta_note_created();
    test_meta_note_fields();
    test_meta_atomic_write();
    done_testing();
}
