package TestHelper;
use Modern::Perl '2018';
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use Exporter qw(import);

our @EXPORT_OK   = qw(setup_test_site teardown_test_site test_config);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub setup_test_site {
    my $tmpdir          = tempdir( CLEANUP => 0 );
    my $source_dir      = "$tmpdir/source";
    my $publication_dir = "$tmpdir/publication";
    mkdir $source_dir      or die "Cannot create $source_dir: $!";
    mkdir $publication_dir or die "Cannot create $publication_dir: $!";
    return {
        tmpdir          => $tmpdir,
        source_dir      => $source_dir,
        publication_dir => $publication_dir,
    };
}

sub teardown_test_site {
    my ( $site ) = @_;
    remove_tree( $site->{ tmpdir } ) if -d $site->{ tmpdir };
}

sub test_config {
    return {
        source_path      => '/tmp/test-source',
        publication_path => '/tmp/test-publication',
        base_uri         => 'http://example.com',
        show_max_posts   => 5,
        author           => 'Test Author',
        site_name        => 'Test Site',
        site_subtitle    => 'A test site',
    };
}

1;
