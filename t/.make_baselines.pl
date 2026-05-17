#!/usr/bin/env perl
use Modern::Perl '2018';

use File::Copy;
use FindBin;

BEGIN {
    if ( !exists $ENV{ BURBLEBOY_HOME } ) {
        $ENV{ BURBLEBOY_HOME } = "$FindBin::Bin/..";
    }
}
use lib "$ENV{BURBLEBOY_HOME}/lib";

use JSON;
use Path::Class::Dir;
use Burbleboy;

Main();
exit;

#-------------------
# Subroutines
#-------------------
sub Main {
    my $baseline_dir =
        Path::Class::Dir->new( $FindBin::Bin, "baselines/new-site/docroot" );
    say "Removing old baselines";
    $baseline_dir->rmtree;
    $baseline_dir->mkpath;

    my $burbleboy = Burbleboy->new;
    $burbleboy->config->path( "$FindBin::Bin/init/new-site" );

    if ( -d $burbleboy->config->path ) {
        $burbleboy->config->path->rmtree;
    }
    say "Creating a default temp site";
    $burbleboy->config->initialize;

    say "Copying in source models";
    my $sources_dir = Path::Class::Dir->new( $FindBin::Bin, "source_model" );
    for my $file ( sort glob( "$FindBin::Bin/source_model/*" ) ) {
        my $src = Path::Class::File->new( $file );
        say "Copying " . $src->basename;
        copy( $src, $burbleboy->config->source_directory )
            or die( "assert - $!" );
        sleep( 1 )
            ;    # the sources need different timestamps for stable baselines
    }

    for my $file ( sort glob( "$FindBin::Bin/source_notes/*" ) ) {
        my $src = Path::Class::File->new( $file );
        say "Copying " . $src->basename;
        copy( $src, $burbleboy->config->source_notes_directory );
        sleep( 1 );
    }

    say "Publishing temp site";
    $burbleboy->publish_all( verbose => 1 );

    say "Creating recent post list";

    my $baseline_recent =
        Path::Class::File->new( $baseline_dir, "../recent_list.json" );
    my $got_recent     = $burbleboy->get_recent_posts;
    my @recent_sources = map { $_->source_file->basename } @$got_recent;
    $baseline_recent->spew( JSON::to_json( \@recent_sources ) );

    say "Moving published docroot to " . $baseline_dir;
    for my $pub ( $burbleboy->config->publication_directory->children ) {
        next if -d $pub;
        my $trg = Path::Class::File->new( $baseline_dir, $pub->basename );
        say "$pub -> $trg";
        copy( $pub, $trg ) || die( "assert: $!" );
    }

    say "Removing temp site";
    $burbleboy->config->path->rmtree;

    say "Remember to check new baselines into git";
}
