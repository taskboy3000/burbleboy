use Modern::Perl '2018';

use FindBin;

BEGIN {
    $::gLIBDIR  = "$FindBin::Bin/../lib";
    $::gBINDIR  = "$FindBin::Bin/../bin";
    $::gTLIBDIR = "$FindBin::Bin/lib";
}
use lib $::gLIBDIR, $::gTLIBDIR;

use Burbleboy::Config qw(home_dir);
use Test2::V0;

Main();
exit;

#-------
# Tests
#-------
sub TestCompileModules {
    my @classFiles = sort glob( "$::gLIBDIR/*.pm" ),
        glob( "$::gLIBDIR/*/*.pm" ),
        glob( "$::gLIBDIR/*/*/*.pm" ),
        glob( "$::gTLIBDIR/*.pm" );

    for my $classFile ( @classFiles ) {
        my @cmd = ( $^X, "-I$::gLIBDIR", "-wc", $classFile, "2>/dev/null" );

        # diag(join(" ", @cmd));

        system( join( " ", @cmd ) );

        my $ok = 0;
        if ( $? == -1 ) {
            printf( "Could not execute: %s\n", join( " ", @cmd ) );
        } elsif ( $? && 127 ) {

            # Expected with bad compiles
        } else {
            $ok = 1;
        }

        ok( $ok, "Compiling : $classFile" );
    }
}

sub TestCompileExecuteables {
    my @binFiles = sort glob( "$::gBINDIR/*" );

    for my $binFile ( @binFiles ) {
        my @cmd = ( $^X, "-I$::gLIBDIR", "-wc", $binFile, "2>/dev/null" );

        system( join( " ", @cmd ) );

        my $ok = 0;
        if ( $? == -1 ) {
            printf( "Could not execute: %s\n", join( " ", @cmd ) );
        } elsif ( $? && 127 ) {

            # Expected with bad compiles
        } else {
            $ok = 1;
        }

        ok( $ok, "Compiling : $binFile" );
    }

}

sub test_home_dir {
    local $ENV{ HOME } = '/custom/home';
    local $ENV{ USERPROFILE };
    is( home_dir(), '/custom/home', 'home_dir respects $ENV{HOME}' );

    local $ENV{ HOME }        = undef;
    local $ENV{ USERPROFILE } = '/user/profile';
    is( home_dir(), '/user/profile',
        'home_dir falls back to $ENV{USERPROFILE}' );

    local $ENV{ HOME }        = undef;
    local $ENV{ USERPROFILE } = undef;
    my $expected = ( getpwuid( $< ) )[ 7 ] || '/tmp';
    is( home_dir(), $expected, 'home_dir falls back to getpwuid or /tmp' );
}

sub Main {

    TestCompileModules();
    TestCompileExecuteables();
    test_home_dir();

    done_testing();
}

