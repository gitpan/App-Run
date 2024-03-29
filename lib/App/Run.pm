package App::Run;
{
  $App::Run::VERSION = '0.03';
}
#ABSTRACT: Create simple (command line) applications

use strict;
use warnings;
use v5.10;

use Carp;
use Try::Tiny;
use Clone qw(clone);
use Scalar::Util qw(reftype blessed);
use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log :Dlog with_logger set_logger), -default_logger =>
    Log::Contextual::WarnLogger->new({ env_prefix => 'APP_RUN' });
use Log::Log4perl qw();
use File::Basename qw();
use Config::Any;

our $CALLPKG;

sub import {
    my $pkg = shift;
    $CALLPKG = caller(0);

    no strict 'refs';
    if (@_ and $_[0] eq 'script') {
      my $app;
        my $run = sub {
            my $opts = shift;
            *{"${CALLPKG}::OPTS"} = \$opts;
            @ARGV = @_;
#         set_logger $app->logger;
        };
#      foreach my $name (qw(log_error)) {
#         *{"${CALLPKG}::$name"} = \*{ $name };
#      }
      $app = App::Run->new($run);
      $app->run_with_args(@ARGV);
   }
   # TODO: require_version 
}


sub new {
    my $self = bless { }, shift;

    $self->app( shift );
    $self->{options} = { @_ };

    $self;
}


sub parse_options {
    my $self = shift;

    local @ARGV = @_;

    require Getopt::Long;
    my $parser = Getopt::Long::Parser->new(
        config => [ "no_ignore_case", "pass_through" ],
    );

    my $options = $self->{options};

    my ($help,$version);
    $parser->getoptions(
        "h|?|help"   => \$help,
        "v|version"  => \$version,
        "q|quiet"    => sub { $options->{loglevel} = 'ERROR' },
        "c|config=s" => sub { $options->{config} = $_[1] },
    );

    if ($help) {
        require Pod::Usage;
        Pod::Usage::pod2usage(0);
    }

    if ($version) {
        say $self->name." ".($self->version // '(unknown version)');
        exit;
    }

    my @args;
    while (defined(my $arg = shift @ARGV)) {
        if ($arg =~ /^([^=]+)=(.+)/) {
            my @path = split /\./, $1;
            my $hash = $options;
            while( @path > 1 ) {
                my $e = shift @path;
                $hash->{$e} //= { };
                $hash = $hash->{$e};
            }
            $hash->{ $path[0] } = $2
                if (reftype($hash)||'') eq 'HASH';
        } else {
            push @args, $arg;
        }
    }

    $options->{config} = ''
        unless exists $options->{config};

    return @args;
}


sub load_config {
    my ($self, $from) = @_;

    # TODO: log this by using a default logger

    my ($config,$configfile);
    try {
        if ($from) {
            # Config::Any interface sucks
            $config = Config::Any->load_files( {
                files => [$from], use_ext => 1,
                flatten_to_hash => 1,
            } );
        } else {
            $config = Config::Any->load_stems( {
                stems => [$self->name],
                use_ext => 1,
                flatten_to_hash => 1,
            } );
        }
        ($configfile,$config) = %$config;
    } catch {
        $_ //= ''; # where's our error message?!
        croak sprintf("failed to load config file %s: $_",
            ($from || $self->name.".*"));
    };

    if ($config) {
        while (my ($key,$value) = each %$config) {
            $self->{options}->{$key} //= $value;
        }
    }
}


sub init {
    my $self = shift;

    # TODO: also set options with this method?

    $self->enable_logger;

    my $app = $self->app;
    if (blessed $app and $app->can('init')) {
        with_logger $self->logger, sub { $app->init( $self->{options} ) };
    }
}


sub run {
    my $self = shift;

    my $options = clone($self->{options});
    my $config = delete $options->{config};

    # called only the first time
    if ( defined $config ) {
        $self->load_config( $config );
        $self->init;
    }

    # override options
    if (@_ and (reftype($_[0])//'') eq 'HASH') {
        # TODO: use Data::Iterator to merge options (?)
        my $curopt = shift;
        while(my ($k,$v) = each %$curopt) {
            $options->{$k} = $v;
        }
    }

    my @args = @_;
    log_trace { "run with args: ",join(',',@args) };

    $self->enable_logger unless $self->logger;

    my $app = $self->app;

    with_logger $self->logger, sub {
#        Dlog_trace { "run $_" } $cmd, @args;
        try {
            return( (reftype $app eq 'CODE')
                ? $app->( $options, @args )
                : $app->run( $options, @args ) );
        } catch {
            log_error { $_ };
            return undef;
        }
    };
}


sub run_with_args {
    my $self = shift;
    $self->run( $self->parse_options( @_ ) );
}


sub name {
    my $self = shift;
    my $app = $self->app;

    $self->{name} //= $app->name
        if blessed $app and $app->can('name');

    ($self->{name}) = File::Basename::fileparse($0)
        unless defined $self->{name};

    return $self->{name};
}


sub version {
    my $self = shift;

    my $pkg = blessed $self->app;
    if (!$pkg) {
        $pkg = $CALLPKG;
    } elsif( $self->app->can('VERSION') ) {
        return $self->app->VERSION;
    }

    no strict 'refs';
    return ${"${pkg}::VERSION"};
}


sub app {
    my $self = shift;

    if (@_) {
        my $app = shift;
        croak 'app must be code reference or object with ->run'
            unless (reftype($app) // '') eq 'CODE'
                or (blessed $app and $app->can('run'));
        $self->{app} = $app;
    }

    return $self->{app};
}


sub logger {
    my $self = shift;
    return $self->{log4perl} unless @_;

    if (blessed($_[0]) and $_[0]->isa('Log::Log4perl::Logger')) {
        return ($self->{log4perl} = $_[0]);
    }

    croak "logger configuration must be an array reference"
        unless !$_[0] or (reftype($_[0]) || '') eq 'ARRAY';

    my @config = $_[0] ? @{$_[0]} : ({
        class     => 'Log::Log4perl::Appender::Screen',
        threshold => 'WARN'
    });

    my $log = Log::Log4perl->get_logger( __PACKAGE__ );
    foreach my $c (@config) {
        my $app = Log::Log4perl::Appender->new( $c->{class}, %$c );
        my $layout = Log::Log4perl::Layout::PatternLayout->new(
            $c->{layout} || "%d{yyyy-mm-ddTHH::mm} %p{1} %c: %m{chomp}%n" );
        $app->layout( $layout);
        $app->threshold( $c->{threshold} ) if exists $c->{threshold};
        $log->add_appender($app);
    }

    $log->trace( "new logger initialized" );

    return ($self->{log4perl} = $log);
}


sub enable_logger {
    my $self = shift;
    my $options = $self->{options};

    $self->logger( $options->{logger} );
    $self->logger->level( $options->{loglevel} || 'WARN' );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Run - Create simple (command line) applications

=head1 VERSION

version 0.03

=head1 SYNOPSIS

THIS MODULE IS NOT MAINTAINED ANYMORE. Please just 
L<http://neilb.org/2013/07/24/adopt-a-module.html|adopt it> 
or have a look at L<App::Cmd> instead!

    ### shortest form of a script
    use App::Run 'script'; # parses @ARGV and sets $OPTS
    
	...; # your script

    =head1 SYNOPSIS
    
	...your documentation...

    =cut


    ### put script into a sub
    use App::Run;

    sub main {
        my ($opts, @args) = @_;
        ...;
    }

    App::Run->new( \&main )->run_with_args(@ARGV);


    ### put script into a package
    use App::Run;

	{ 
	    package MyApp;
        
		our $VERSION = 1.0; # shown if called with -v

	    sub init {          # called before first run
			my ($opts) = @_;
	        ...; 
	    }

	    sub run {           # main method
            my ($opts, @args) = @_;
			...;
	    }
	}

	App::Run->new( MyApp->new )->run_with_args(@ARGV);

=head1 DESCRIPTION

App::Run provides a boilerplate to build applications that can (also) be
run from command line. The module comes in a single package that facilitates:

=over 4

=item *

Setting configuration values (from file or from command line)

=item *

Initialization

=item *

Logging

=back

App::Run combines L<Pod::Usage>, L<Config::Any>, and L<Log::Contextual>.

=head1 METHODS

=head2 new( $app, [ %options ] )

Create a new application instance, possibly with options.

=head2 parse_options( @ARGV )

Parse command line options, set options from key-value pairs and return the
remaining arguments.  Nested option names are possible separated with a dot:

    myapp foo=bar doz.bar=2

results in the following options

    { foo => "bar", doz => { bar => 2 }

which could also be specified in a YAML configuration file as

    foo: bar
    doz:
      bar: 2

The options are persistently stored in the application object. You should only
call this method once and only for command line applications.

The following arguments are always detected:

    --h, --help, -?           print help with POD::Usage and exit
    --v, --version            print version and exit
    -c FILE, --config FILE    sets option config=file
    --quiet                   sets loglevel=ERROR

The option C<config> is set to the empty string by default.

The method returns remaining arguments as array.

=head2 load_config ( [ $from ] )

Load additional options from config file. The config file is automatically
detected if not explicitly given. Configuration from config file will not
override existing options. Does not initialize the application.

=head2 init

Initialized the app by enabling a logger and calling the wrapped application's
C<init> method (if defined).

=head2 run( [ { $options } ], [ @args ] )

Runs the application.

=head2 run_with_args ( @ARGV )

Shortcut to simply initialize and run a command line application. Equal to:

    $app->run( $app->parse_options( @ARGV ) );

This will also initialize the application before actually running it.

=head2 name

Returns the name of the application. The name is only determinded once, as
return value from C<< $app->name >> (if implemented) or from C<$0>.

=head2 version

Returns the version of the application. The version is determined from the
application's C<VERSION> method or from its C<$VERSION> variable, if it is an
object, or from C<$VERSION> of the package that imported App:Run.  Use method
C<VERSION> instead of C<version> to get the version of App:::Run.

=head2 app ( $app )

Get and/or set the wrapped application as object or code reference.

=head2 logger( [ $logger | [ { %config }, ... ] )

Configure a L<Log::Log4perl> logger, either directly or by passing logger
configuration. Logger configuration consists of an array reference with hashes
that each contain configuration of L<Log::Log4perl::Appender>.  The default
appender, as configured with C<logger(undef)> is equal to setting:

    logger([{
        class     => 'Log::Log4perl::Appender::Screen',
        threshold => 'WARN'
    }])

To simply log to a file, one can use:

    logger([{
        class     => 'Log::Log4perl::Appender::File',
        filename  => '/var/log/picaedit/error.log',
        threshold => 'ERROR',
        syswrite  => 1,
    })

Without C<threshold>, logging messages up to C<TRACE> are catched. To actually enable
logging, a default logging level is set, for instance

    logger->level('WARN');

Use C<logger([])> to disable all loggers.

You should not need to directory call this method but provide configuration
values C<logger> and C<loglevel>, for instance in a YAML config file:

    loglevel: DEBUG
    logger:
      - class:     Log::Log4perl::Appender::File
        filename:  error.log
        threshold: ERROR
      - class:     Log::Log4perl::Appender::Screen
        layout:    "%d{yyyy-mm-ddTHH::mm} %p{1} %C: %m{chomp}%n"

=head2 enable_logger

Set logger and loging level from logging options C<logger> and C<loglevel>.
Logging level is set to C<WARN> by default. You should not need to directly
call this method unless you have changed the logging options.

=head1 SEE ALSO

Configuration is read with L<Config::Any>.

Use L<Log::Contextual> for logging in
your application. See L<Log::Log4perl> for logging configuration.

See L<CLI::Framework> for a more elaborated application framework.

App::Run requires at least Perl 5.10.

This package was somehow inspired by L<plackup>.

=head1 AUTHOR

Jakob Voß <voss@gbv.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
