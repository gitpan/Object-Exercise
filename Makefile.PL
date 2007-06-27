use ExtUtils::MakeMaker;

WriteMakefile
(

  NAME            => 'Object::Exercise',
  VERSION         => 1.10,
  ABSTRACT_FROM   => 'lib/Object/Exercise.pm',
  PREREQ_PM =>
  {
    # current version deals with Time::HiRes issues.

    Benchmark   => 1.07,

    # any version of these will be sufficient.

    map { ( $_ => 0 ) }
    qw
    (
        strict
        Symbol
        IO::Handle
        Scalar::Util

        Test::More
        Test::Deep

        File::Basename
    )
  },

);
