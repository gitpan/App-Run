
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Create simple (command line) applications",
  "AUTHOR" => "Jakob Vo\x{df} <voss\@gbv.de>",
  "BUILD_REQUIRES" => {},
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
  "TEST_REQUIRES" => {
    "Config::Tiny" => 0,
    "Data::Dumper" => 0,
    "File::Temp" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.03",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Clone" => 0,
  "Config::Any" => 0,
  "Config::Tiny" => 0,
  "Data::Dumper" => 0,
  "File::Basename" => 0,
  "File::Temp" => 0,
  "Getopt::Long" => 0,
  "Log::Contextual" => 0,
  "Log::Contextual::WarnLogger" => 0,
  "Log::Log4perl" => 0,
  "Pod::Usage" => 0,
  "Scalar::Util" => 0,
  "Test::More" => 0,
  "Try::Tiny" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



