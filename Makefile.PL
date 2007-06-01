use ExtUtils::MakeMaker;

WriteMakefile
(

  NAME            => 'Object::Exercise',
  VERSION         => 1.04,
  ABSTRACT_FROM   => 'lib/Object/Exercise.pm',
  PREREQ_PM =>
  {
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

        Benchmark
        File::Basename
    )
  },

);
