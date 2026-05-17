use Modern::Perl '2018';
use warnings;
use strict;

use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use FindBin;
use lib "$FindBin::Bin/../lib";

use Test2::V0;

use Burbleboy::Config qw(read_config config_defaults);

Main();
exit;

sub _write_config {
    my ( $dir, $extra ) = @_;
    $extra ||= '';
    mkpath( "$dir/source" );
    mkpath( "$dir/docroot" );
    my $conf = "$dir/burbleboy.conf";
    open my $fh, '>', $conf or die "Cannot write $conf: $!";
    print $fh "base_uri: http://example.com/\n";
    print $fh "title: Test Blog\n";
    print $fh "author_name: Testy McTest\n";
    print $fh "author_email: testy\@example.com\n";
    print $fh "source_path: $dir/source\n";
    print $fh "publication_path: $dir/docroot\n";
    print $fh "template_path: $dir/templates\n";
    print $fh "run_path: $dir/run\n";
    print $fh "log_path: $dir/log\n";
    print $fh "source_notes_path: $dir/notes\n";
    print $fh "notes_publication_path: $dir/docroot/notes\n";
    print $fh "show_max_posts: 5\n";
    print $fh "site_description: A test blog\n";
    print $fh "image:\n";
    print $fh "image_alt: [image]\n";
    print $fh "$extra\n" if $extra;
    close $fh;
    return $conf;
}

sub test_config_defaults {
    my $defaults = config_defaults();
    ok ref( $defaults ) eq 'HASH', 'config_defaults returns a hashref';
    ok exists $defaults->{ author_email },   'defaults has author_email';
    ok exists $defaults->{ author_name },    'defaults has author_name';
    ok exists $defaults->{ title },          'defaults has title';
    ok exists $defaults->{ base_uri },       'defaults has base_uri';
    ok exists $defaults->{ show_max_posts }, 'defaults has show_max_posts';
}

sub test_read_config_returns_hashref {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $conf   = _write_config( $tmpdir );
    my $config = read_config( $conf );
    ok ref( $config ) eq 'HASH', 'read_config returns a hashref';
    ok defined $config->{ base_uri }, 'base_uri is defined';
    ok defined $config->{ title },    'title is defined';
}

sub test_path_to_directory_mapping {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $conf   = _write_config( $tmpdir );
    my $config = read_config( $conf );
    ok exists $config->{ source_directory },
        '_path key mapped to _directory: source_directory exists';
    ok exists $config->{ publication_directory },
        'publication_directory exists';
    ok exists $config->{ template_directory }, 'template_directory exists';
    ok exists $config->{ run_directory },      'run_directory exists';
    ok exists $config->{ log_directory },      'log_directory exists';
    ok exists $config->{ source_notes_directory },
        'source_notes_directory exists';
    ok exists $config->{ notes_publication_directory },
        'notes_publication_directory exists';
    is $config->{ source_directory }, "$tmpdir/source",
        'source_directory value matches source_path';
    is $config->{ publication_directory }, "$tmpdir/docroot",
        'publication_directory value matches publication_path';
}

sub test_missing_file_dies {
    my $tmpdir  = tempdir( CLEANUP => 1 );
    my $missing = "$tmpdir/nonexistent.conf";
    eval { read_config( $missing ); };
    ok $@, 'read_config dies on missing file';
}

sub test_missing_required_keys_dies {
    my $tmpdir     = tempdir( CLEANUP => 1 );
    my $bad_config = "$tmpdir/bad.conf";
    open my $fh, '>', $bad_config or die "Cannot write $bad_config: $!";
    print $fh "title: Incomplete\n";
    close $fh;

    eval { read_config( $bad_config ); };
    ok $@, 'read_config dies when required directory keys are missing';
    like $@, qr/source_path/, 'error mentions missing source_directory';
}

sub test_all_expected_keys_present {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $conf   = _write_config( $tmpdir );
    my $config = read_config( $conf );
    for my $key (
        qw(
        base_uri title author_name author_email
        source_directory publication_directory template_directory
        run_directory log_directory
        source_notes_directory notes_publication_directory
        show_max_posts site_description
        )
        )
    {
        ok exists $config->{ $key }, "key '$key' is present in config";
    }
}

sub test_invalid_base_uri_dies {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $conf   = "$tmpdir/bad_uri.conf";
    mkpath( "$tmpdir/source" );
    open my $fh, '>', $conf or die "Cannot write $conf: $!";
    print $fh "base_uri: ftp://invalid\n";
    print $fh "title: Test\n";
    print $fh "author_name: Test\n";
    print $fh "author_email: t\@t.com\n";
    print $fh "source_path: $tmpdir/source\n";
    print $fh "publication_path: $tmpdir/pub\n";
    close $fh;

    eval { read_config( $conf ); };
    ok $@, 'read_config dies on non-http base_uri';
    like $@, qr/base_uri/i, 'error mentions base_uri';
}

sub test_source_directory_missing_dies {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $conf   = "$tmpdir/no_src.conf";
    open my $fh, '>', $conf or die "Cannot write $conf: $!";
    print $fh "base_uri: http://example.com/\n";
    print $fh "title: Test\n";
    print $fh "author_name: Test\n";
    print $fh "author_email: t\@t.com\n";
    print $fh "source_path: $tmpdir/nonexistent\n";
    print $fh "publication_path: $tmpdir/pub\n";
    close $fh;
    mkpath( "$tmpdir/pub" );

    eval { read_config( $conf ); };
    ok $@, 'read_config dies when source_directory missing';
    like $@, qr/source.*directory/i, 'error mentions source directory';
}

sub test_publish_directory_created {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $conf   = "$tmpdir/new_pub.conf";
    mkpath( "$tmpdir/source" );
    open my $fh, '>', $conf or die "Cannot write $conf: $!";
    print $fh "base_uri: http://example.com/\n";
    print $fh "title: Test\n";
    print $fh "author_name: Test\n";
    print $fh "author_email: t\@t.com\n";
    print $fh "source_path: $tmpdir/source\n";
    print $fh "publication_path: $tmpdir/new_pub\n";
    close $fh;

    my $config = read_config( $conf );
    ok -d "$tmpdir/new_pub",
        'read_config creates publication_directory if missing';
}

sub Main {
    test_config_defaults();
    test_read_config_returns_hashref();
    test_path_to_directory_mapping();
    test_missing_file_dies();
    test_missing_required_keys_dies();
    test_all_expected_keys_present();
    test_invalid_base_uri_dies();
    test_source_directory_missing_dies();
    test_publish_directory_created();
    done_testing();
}
