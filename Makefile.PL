use ExtUtils::MakeMaker;

WriteMakefile
(

  NAME            => 'Object::Exercise',
  VERSION         => 1.01,
  ABSTRACT_FROM   => 'lib/Object/Exercise.pm',
  PREREQ_PM =>
  {
    # standard distro, particular versions 
    # are unlikely to cause pain.

    map { ( $_ => 0 ) }
    qw
    (
        strict
        Symbol
        Scalar::Util

        Test::More
        Test::Deep

        Benchmark
        File::Basename
    )
  },

);
