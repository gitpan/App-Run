
use strict;
use warnings;

use 5.010000;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Create simple (command line) applications",
  "AUTHOR" => "Jakob Vo\303\237 <voss\@gbv.de>",
  "BUILD_REQUIRES" => {
    "Config::Tiny" => 0,
    "Data::Dumper" => 0,
    "File::Temp" => 0,
    "Test::More" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "App-Run",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "App::Run",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Clone" => 0,
    "Config::Any" => 0,
    "File::Basename" => 0,
    "Getopt::Long" => 0,
    "Log::Contextual" => 0,
    "Log::Contextual::WarnLogger" => 0,
    "Log::Log4perl" => 0,
    "Pod::Usage" => 0,
    "Scalar::Util" => 0,
    "Try::Tiny" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



