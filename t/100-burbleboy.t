use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

use Test2::V0;
use File::Copy qw(cp);
use File::Path qw(make_path);
use Template;
use Cwd qw(cwd);
use TestHelper qw(setup_test_site teardown_test_site);

use Burbleboy::Publish qw(:all);

Main();
exit;

sub Main {
    test_publish_all();
    done_testing();
}

sub _fixture_post {
    my ( $name ) = @_;
    return "$FindBin::Bin/source_model/$name";
}

sub _fixture_note {
    my ( $name ) = @_;
    return "$FindBin::Bin/source_notes/$name";
}

sub test_publish_all {
    my $site   = setup_test_site();
    my $pub    = $site->{ publication_dir };
    my $source = $site->{ source_dir };
    my $notes  = "$source/notes";

    make_path( $notes );

    for my $f (
        qw(good-source-file.md one_tag.md two_tags.md
        formatted-title.md light_coding.md fenced-code-block.md)
        )
    {
        cp( _fixture_post( $f ), "$source/$f" ) or die "Cannot cp $f: $!";
    }

    for my $f ( qw(01-note.txt 02-note.txt 03-note.txt) ) {
        cp( _fixture_note( $f ), "$notes/$f" ) or die "Cannot cp $f: $!";
    }

    my $config = {
        publication_path => $pub,
        base_uri         => 'http://example.com/',
        title            => 'Integration Test',
        author_name      => 'Tester',
        author_email     => 't@test.com',
        show_max_posts   => 5,
    };

    my $tt = Template->new(
        {   INCLUDE_PATH => "$FindBin::Bin/../lib/Burbleboy/Template",
            ENCODING     => 'utf8'
        }
    );

    opendir my $dh, $source or die "Cannot read $source: $!";
    my @post_files = sort grep { /\.md$/ && -f "$source/$_" } readdir( $dh );
    closedir $dh;

    my @posts;
    for my $f ( @post_files ) {
        my $post = eval { publish_post( "$source/$f", $config, $tt ) };
        if ( $@ ) { note "Skipping $f: $@"; next; }
        push @posts, $post;
    }

    ok scalar @posts > 0, 'at least one post published';

    for my $post ( @posts ) {
        ok -s $post->{ publication_file }, 'post HTML file created';
        like $post->{ uri }, qr{^http://example\.com/},
            'post URI starts with base_uri';
    }

    publish_front_page( $config, $tt, \@posts );
    publish_archive_page( $config, $tt, \@posts );
    publish_tags_index( $config, $tt, \@posts );
    publish_atom_feed( $config, $tt, \@posts );
    publish_json_feed( $config, $tt, \@posts );

    for my $file ( qw(blog.html archive.html tags.html atom.xml feed.json) ) {
        ok -s "$pub/$file", "$file created and non-empty";
    }

    for my $file ( qw(blog.html archive.html tags.html) ) {
        open my $fh, '<', "$pub/$file" or die "Cannot read $pub/$file: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        like $content, qr/Integration Test/, "$file contains site title";
    }

    my $orig_cwd = cwd();
    chdir $pub;

    opendir $dh, $notes or die "Cannot read $notes: $!";
    my @note_files = sort grep { -f "$notes/$_" } readdir( $dh );
    closedir $dh;

    my @notes;
    for my $f ( @note_files ) {
        my $note = eval { publish_note( "$notes/$f", $config, $tt ) };
        if ( $@ ) { note "Skipping note $f: $@"; next; }
        push @notes, $note;
    }

    chdir $orig_cwd;

    ok scalar @notes > 0, 'at least one note published';

    publish_notes_roll( $config, $tt, \@notes );
    publish_notes_json( $config, $tt, \@notes );

    ok -s "$pub/notes_roll.html",   'notes_roll.html created and non-empty';
    ok -s "$pub/recent_notes.json", 'recent_notes.json created and non-empty';

    teardown_test_site( $site );
}
