package Burbleboy::Config;
use Modern::Perl '2018';

use Exporter qw(import);
our @EXPORT_OK   = qw(read_config config_defaults home_dir);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

our $VERSION = "1.0";

sub config_defaults {
    return {
        author_email     => 's.handwich@localhost',
        author_name      => 'Sam Handwich',
        title            => 'Another Burbleboy Blog',
        base_uri         => 'http://localhost/',
        site_description => '',
        engine_name      => 'burbleboy/taskboy3000',
        engine_uri       => 'https://github.com/taskboy3000/burbleboy',
        engine_version   => '1.0',
        image_alt        => '[image]',
        show_max_posts   => 5,
        custom_nav_items => [],
        enable_replies   => 0,
    };
}

sub read_config {
    my ( $file ) = @_;

    die "Config file '$file' not found" unless $file && -f $file;

    my $config = do {
        require YAML::XS;
        YAML::XS::LoadFile( $file );
    };

    die "Config file '$file' is empty or invalid"
        unless $config && ref $config eq 'HASH';

    for my $key ( keys %$config ) {
        if ( $key =~ /^(\w+)_path$/ ) {
            $config->{ "${1}_directory" } = delete $config->{ $key };
        }
    }

    my $defaults = config_defaults();
    for my $key ( keys %$defaults ) {
        $config->{ $key } //= $defaults->{ $key };
    }

    my @required = qw(base_uri title author_name author_email);
    my @missing;
    for my $key ( @required ) {
        my $found;
        for my $variant ( $key, "${key}_directory", "${key}_path" ) {
            if ( exists $config->{ $variant }
                && defined $config->{ $variant } )
            {
                $found = 1;
                last;
            }
        }
        push @missing, $key unless $found;
    }

    if ( !exists $config->{ source_directory } && !exists $config->{ path } )
    {
        push @missing, 'source_path/source_directory';
    }
    if (   !exists $config->{ publication_directory }
        && !exists $config->{ path } )
    {
        push @missing, 'publication_path/publication_directory';
    }

    die "Missing required config keys: " . join( ', ', @missing ) if @missing;

    if ( my $src = $config->{ source_directory } ) {
        die "Source directory '$src' does not exist"
            unless -d $src;
    }

    if ( my $pub = $config->{ publication_directory } ) {
        unless ( -d $pub ) {
            require File::Path;
            File::Path::mkpath( $pub )
                or die "Cannot create publication directory '$pub': $!";
        }
    }

    if ( my $uri = $config->{ base_uri } ) {
        die "base_uri '$uri' must start with http:// or https://"
            unless $uri =~ m{^https?://}i;
    }

    return $config;
}

sub home_dir {
    return
           $ENV{ HOME }
        || $ENV{ USERPROFILE }
        || ( getpwuid( $< ) )[ 7 ]
        || '/tmp';
}

sub new {
    my $class  = shift;
    my %params = @_;

    my $config_file =
        $params{ config_file } || home_dir() . '/.burbleboy.conf';
    my $config;
    if ( -f $config_file ) {
        $config = read_config( $config_file );
    } else {
        $config = config_defaults();
    }

    $config->{ config_file } ||= $config_file;

    for my $key ( keys %params ) {
        $config->{ $key } = $params{ $key };
    }

    my $self = bless $config, $class;
    return $self;
}

sub AUTOLOAD {
    our $AUTOLOAD;
    my $self   = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;

    return if $method eq 'DESTROY';

    if ( $method =~ /^has_(.+)/ ) {
        my $key = $1;
        return exists $self->{ $key } && defined $self->{ $key } ? 1 : 0;
    }

    if ( @_ ) {
        $self->{ $method } = shift;
        return $self;
    }

    if ( $method =~ /^(.+)_directory$/ ) {
        my $dir_key = $1;
        if ( exists $self->{ $method } ) {
            require Path::Class::Dir;
            return Path::Class::Dir->new( $self->{ $method } );
        }
        if ( exists $self->{ $dir_key } ) {
            require Path::Class::Dir;
            return Path::Class::Dir->new( $self->{ $dir_key } );
        }
    }

    if ( $method eq 'path' ) {
        my $val = $self->{ path } || './new-site';
        require Path::Class::Dir;
        return Path::Class::Dir->new( $val );
    }

    return $self->{ $method } if exists $self->{ $method };

    if ( $method eq 'datetime_formatter' ) {
        require DateTime::Format::W3CDTF;
        return DateTime::Format::W3CDTF->new;
    }

    if ( $method eq 'base_uri' || $method eq 'webmention_endpoint' ) {
        if ( my $val = $self->{ $method } ) {
            require URI;
            return URI->new( $val );
        }
        return;
    }

    if ( $method eq 'config_tt' ) {
        require Template;
        my $template_dir = $self->{ template_directory }
            || "$ENV{BURBLEBOY_HOME}/lib/Burbleboy/Template";
        return Template->new(
            INCLUDE_PATH => $template_dir,
            ABSOLUTE     => 1,
            RELATIVE     => 1,
        );
    }

    if ( $method eq 'config_template_dir' ) {
        require Path::Class::Dir;
        return Path::Class::Dir->new( $ENV{ BURBLEBOY_HOME },
            "lib", "Burbleboy", "Template" );
    }

    if ( $method eq 'config_file' ) {
        return $self->{ config_file } || home_dir() . '/.burbleboy.conf';
    }

    if ( $method eq 'serialize' || $method eq 'unserialize' ) {
        return;
    }

    if ( $method eq 'initialize' ) {
        require File::Path;
        require File::Copy;
        for my $dir_key (
            qw(log_directory notes_publication_directory path publication_directory run_directory source_directory source_notes_directory template_directory)
            )
        {
            my $dir = $self->$dir_key;
            next                       unless ref $dir;
            File::Path::mkpath( $dir ) unless -d $dir;
        }
        return;
    }

    require Carp;
    Carp::croak( "No such config key: $method" );
}

1;
