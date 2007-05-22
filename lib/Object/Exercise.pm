# $Id: Exercise.pm 32 2007-05-22 23:05:01Z lembark $
#######################################################################
# housekeeping
#######################################################################

package Object::Exercise;

use strict;

use Symbol;
use Data::Dumper;

use Scalar::Util qw( reftype );

########################################################################
# package variables
########################################################################

our $VERSION    = 0.30;

my $cmp_struct  = '';    

# use to control breakpoints within the loop.
# our necessary to permit use of local.

our $debug      = '';

# handle iterations: verbose controls reporting, 
# continue ignores errors in the eval of a command. 

my $verbose     = '';
my $continue    = '';

# dispatch table for loop commands.
# these are non-ref elements in the work queue.

my %parmz =
(
    # print anything unknown.

    ''          => sub { print STDERR $_ },

    # otherwise set the appropriate variable.

    debug       => sub { $debug     = 1 },
    nodebug     => sub { $debug     = 0 },

    continue    => sub { $continue  = 1 },
    nocontinue  => sub { $continue  = 0 },

    verbose     => sub { $verbose   = 1 },
    noverbose   => sub { $verbose   = 0 },
    quiet       => sub { $verbose   = 0 },
);

for
(
    [ qw( quiet     noverbose   ) ],
    [ qw( break     debug       ) ],
    [ qw( single    debug       ) ],
)
{
    my( $alias, $existing ) = @$_;

    $parmz{ $alias } = $parmz{ $existing }
    and next;

    die "Invalid alias '$alias' for unknown '$existing'"
}


########################################################################
# utility subs
########################################################################

my $log_message
= sub
{
    local $Data::Dumper::Purity     = 0;
    local $Data::Dumper::Terse      = 1;
    local $Data::Dumper::Indent     = 1;
    local $Data::Dumper::Deparse    = 1;
    local $Data::Dumper::Sortkeys   = 1;
    local $Data::Dumper::Deepcopy   = 0;
    local $Data::Dumper::Quotekeys  = 0;

    local $, = "\n";

    print STDERR map { ref $_ ? Dumper $_ : $_ } @_, '';

    ()
};

my $handle_error
= sub
{
  my $cmd = pop;

  $log_message->( @_ );

  local $debug  = 1;

  $DB::single   = 1;

  # at this point &$cmd can be re-executed
  # with its own breakpoint set via $debug.

  0
};

my $gen_command
= sub
{
    my( $obj, $argz ) = @_;

    my $method = shift @$argz;

    sub
    {
        $DB::single = 1 if $debug;

        $obj->$method( @$argz )
    }
};

########################################################################
# handle one element of the list

my %ref_handlerz =
(
    ARRAY =>
    sub
    {
        # this is the most common place to end up: dealing with
        # an action + test or just an action.
        #
        # determine if this is a test (two arrayrefs)
        # or just a command (one arrayref).
        # append a message to the test if it isn't
        # already three items long.

        my( $obj, $element  ) = @_;

        my $argz    = '';
        my $expect  = '';
        my $method  = '';
        my $message = '';
        my $compare = '';
        my $ignore  = '';

        if
        (
            1 <= @$element
            &&
            'ARRAY' eq reftype $element->[0]
            &&
            'ARRAY' eq reftype $element->[1]
        )
        {
            ( $argz, $expect, $message ) = @$element;

            $compare    = 1;
            $ignore     = $continue || ( $expect eq '' );

            $message ||= join ' ', @$argz;
        }
        else
        {
            @$argz = @$element;

            $message = join ' ', @$argz , '->', @$expect;
        }

        my $cmd     = $gen_command->( $obj, $argz );

        my $result  = eval { [ &$cmd ] };

        if( $@ && $ignore )
        {
            $log_message->( "Expected failure: $message", $argz )
            if $verbose;
        }
        elsif( $@ )
        {
            $handle_error->( "Failed execute: $message", $cmd );
        }
        elsif( $compare )
        {
            $cmp_struct->( $result, $expect, $message )
            or $handle_error->
            (
                "Failed compare: $message",
                'Found:',   $result,
                'Expect:',  $expect,
                $cmd
            );
        }
        elsif( $verbose )
        {
            $log_message->( "Successful: $message" );
        }
    },

    CODE =>
    sub
    {
        # re-dispatch the thing with the object first
        # on the stack.

        my $action = splice @_, 1, 1;

        eval { &$action };

        $@ or return;

        if( $continue )
        {
            $log_message->( "Failure: $@", $action )
            if $verbose;
        }
        else
        {
            $handle_error->( "Failure: $@", sub { &$action } );
        }
    },
);

########################################################################
# benchmark, execution handlers

my $benchmark
||= sub
{
    # add the logging message, then replace the arguments with
    # the lookup result -- see arg order for Test::Deep.

    use Benchmark qw( :hireswallclock );
    use File::Basename;

    my $base    = basename $0;

    my $t0      = Benchmark->new;

    my $obj     = shift;

    my $count   = 0;
    my $errors  = 0;

    TEST:
    for( @_ )
    {
        if( ref $_ )
        {
            ++$count;

            my $argz    = ref $_->[0] ? $_->[0] : $_;

            my $method  = shift @$argz;

            eval { $obj->$method( @$argz ) };

            next unless $@;

            $log_message->( 'Error:', $@, 'Executing:', $method, $argz );

            ++$errors;

            last unless $continue;
        }
    }

    my $diff = timestr timediff $t0, Benchmark->new;

    $log_message->
    (
        "Benchmark $base: $diff",
        "Executing: $count items, $errors errors",
    );
};

my $run_tests
||= sub
{
    use Test::More;
    use Test::Deep qw( cmp_deeply  );

    $cmp_struct = Test::Deep->can( 'cmp_deeply' );

    my $obj = shift;

    my $test_count
    = grep
    {
        (ref $_)              # ignore breaks
        &&
        (ref $_ eq q{ARRAY})  # check for array
        &&
        (ref $_->[0])         # expected value is initial
    }
    @_;

    if( $test_count )
    {
        plan tests => $test_count;

        $log_message->( "Executing: $test_count tests" )
        if $verbose;
    }
    else
    {
        plan tests => 1;
    }

    TEST:
    for( @_ )
    {
        # If the next item is not a reference at all --
        # e.g., if it's a string such as 'break' --
        # set $debug to true value and try the next test.

        if( my $type = reftype $_ )
        {
            my $handler = $ref_handlerz{ $type }
            or die "Unable to handle item of type '$type'";

            $obj->$handler( $_ );
        }
        elsif( 0 < ( my $i = index $_, '=' ) )
        {
            my $key = substr $_, 0, $i;
            my $val = substr $_, ++$i;

            $obj->{ $key } = $val;
        }
        elsif( my $handler = $parmz{ $_ } )
        {
            &$handler
        }
        else
        {
            # display the message and keep going.

            $log_message->( $_ );
        }
    }

    pass "Execution complete" unless $test_count;
};

########################################################################
# subroutines
########################################################################

sub import
{
    # discard the class argument.

    shift;

    # arguments:
    # -k turns off fatal on error.
    # -v turns on  verbose.
    # -b uses benchmark if env doesn't set it first.

    my $name    = 'exercise';

    my $sub     = $run_tests;

    for( @_ )
    {
        if( /-k/ )
        {
            $continue = 1;
        }
        elsif( /-v/ )
        {
            $verbose = 1;
        }
        elsif( /-b/ )
        {
            $sub = $benchmark;
        }
        elsif( /-n/ )
        {
            ( $name ) = / (\w+) $/x
            or die "Bogus -n switch: no name found in '$_'";
        }
    }

    # push the configured object out to whatever the 
    # caller asked for (default 'exercise').

    $log_message->( "Installing '$sub' as '$name'" )
    if $verbose;

    my $caller  = caller;

    my $ref     = qualify_to_ref $name, $caller;

    *$ref       = \$sub;

    return
}

# keep require happy

1

__END__

=head1 NAME

Object::Exercise - Generic execution & benchmark harness for method calls.

=head1 SYNOPSIS

  use Object::Exercise;

  my @operationz =
  (
    [
      [ method arg arg arg ... ]          # method and arguments
      [ 1 ],                              # expected value
    ],

    [
      qw( method arg arg arg )            # just check for $@
    ],

    [
      [ qw( method expected to fail ) ]   # continue on failure
      [],
    ],

    [
      [ $coderef, @argz ],                # $obj->$coderef( @argz )
      [ ( 1 .. 10 )     ],                # expected value
      'Coderef returns list'              # hardwired message
    ]
  );

  # You can push the operations through an class:

  $exercise->( 'YourClass', @test_opz );    # YourClass->method( @argz )

  # or an object:

  my $object = YourClass->new( @whatever );

  $object->prepare_for_test( @more_args );

  $exercise->( $object,     @test_opz );    # $object->method( @argz )


=head1 DESCRIPTION

This package exports a single subroutine , C<exercise>, which
functions as an OO execution loop.

C<$execute> is a subroutine reference that takes a list of arguments.  The
first element in that list is an object of the class being tested.  The
remaining elements are a list of operations, each of which is an array
reference.

Each operation consists of a method call and the method's arguments. Each
method call is dispatched using the object, optionally comparing the return
value to some pre-defined result.

Exceptions are trapped and logged.  The last operation can be re-executed if
it fails.

All operations are passed in as arrayrefs. They can be nested either to store
a return value and test to run, or to hold a list consisting of a method name
and its arguments.

=head2 Rationale

The setup code for a typical test file is frequently repetitive.  We have to
code for the object and each of a collection of method calls. We frequently
have to check return values and exception statuses.

This leads to blocks of code like this:

  my $obj = Package::New->( ... );

  if( defined ( my $return = eval { $obj->method_1( @args_1 ) } ) )
  {
    @$return == 3 or die "...";

    cmp_deeply $return, [ ... ], "Failed comparing @argz_1: ...";

  }
  elsif( $@ )
  {
    die "Failed execution of method_1 ...";
  }
  else
  {
    die "Undef returned from method_1 ..."
  }

  eval { $obj->method_2( @args_2 ) };

  if( $@ )
  {
    die "Failed execution of method_2 ...";
  }
  ...

The only thing that really varies about any of these
are the return values, method name, and arguments.

Object::Exercise reduces all of this to a list of
methods and arguments, with optional data validation:


  [ method => @args ],      # single flat list in arrayref

or

  [
    [ method => @args ]     # same method + arguments
    [ 3 ],                  # with added return value check
  ],


In both cases $@ is checked on return; in the second
case Test::Deep::cmp_deeply is used to validate the
returned data.

=head2 Test vs. Run-Only Operations

There are two types of operations: tests and run-only.
Tests have a hard-coded value that is compared with the
method call's return value; the return value of a run-only
operation is ignored.

=over 4

=item Tests

These are nested arrayrefs:

  [
    [ $method => @args  ],
    [ expected return   ],
    'optional message'
  ],

The return value can be any sort of structure but must
be enclosed in an arrayref. The test is run via:

  my $result = [ $object->$method( @argz ) ];

  cmp_deeply $result, $expected, $message;

This leaves any method called in a list context with
the result put into an arryref. This means that the
expected value for a call that returns arrayrefs will
look like:

  [
    [ $method => @argz ],
    [ # outer arrayref stored return value

      [ # return value is itself an arrayref ]
    ],
  ],

If the method returns hashrefs in list context then
use something like:

  [
    [ $method => @argz ],
    [ # outer arrayref stored return value

      { # return value is itself an hashref }
    ],
  ],

The default C<ok> message is formed by joining the 
method and arguments on whitespace. This can lead to 
prove issuing lines like:

  ok save foobar HASH(0x123456) (999)

but usually gives at least recognizable results.

To override this, simply supply a message of your own:

  [
    [ $method => @argz ],
    [ { # return value is itself an hashref } ],
    'Remember: This should return a hashref!'       # your message
  ],

=item Testing Known Failures

Sometimes it is useful to test how the code handles
invalid requests. In these cases the test will fail.
Normally, executing a method that returns with C<$@> set
will be logged as a failed test. If the expected value
is an empty array ref (i.e., nothing was expected back)
then the C<$@> will be logged as passed.

These tests look like:

  [
    [ qw( method designed to fail ) ]
    '',
  ]

This will give a message like:

  ok save foobar HASH(0x123456) expected failure (999)


=item Run-Only Items

These consist simply of a method and its arguments:

  [ method => arg, arg, ...  ],

A method with no arguments is a one-liner:

  [ method ]

which leads to:

  $object->$method()

These are called in a void context, so if the method
checks C<wantarray> it will get undef. This may affect
the execution of some methods, but usually will not
(normal tests are C<wantarray ? a : b> without the
separate test for C<defined>).

=back

=item Coderefs

Coderef's are dispatched as standard method calls:

    my $coderef = sub { ... };  # or \&somesub


    [
        [ $coderef, @argz ],
        [ ... ]
    ]

is executed as:

    $obj->$coderef( @argz )

this allows dispatching the object outside of its class,
say to a utility function that does some extra data checking
or logging.

=head2 Re-Running Failed Operations

Operations are deemed to fail if they raise an
exception (I<i.e.>, C<$@> is set at their completion) or if
the return value does not compare deeply to expected
data (if provided).

In either case, it is often helpful to examine the
failed operation. This is accomplished here by
wrapping each exectution in a closure like:

  my $cmd
  = sub
  {
    $DB::single = 1 if $debug;

    $obj->$method( @argz )
  };

These closures are C<eval>-ed one at a time and then compared
to expected values as necessary. If the operation raises
an exception or the test fails then C<$debug> is set to true
and a breakpoint is set in the main loop. This allows code
run in the perl debugger to re-execute the failed
operation in single-step mode and see exactly what failed
without having to single-step through all of the
successful operations.

For example:

  perl -d harness_code.t;

will stop execution at the first failed operation, allowing
a single C<s> to step into the C<$obj->$method( @argz )> call.

=head2 Harness Directives

There are times when you want to control the execution
or harness arguments as it is running. The directives
are processed by the harness itself. These can set a 
breakpoint prior to calling one of the methods, adjust
the verbosity, set the continue switch, or set an object
value.

=head3 Breakpoints

It is sometimes helpful to stop the execution of code
before it fails in order to examine its execution before
the failure. Any non-ref entry in the data will print the
text and set the debug flag to true. After that every
operation will halt at the C<$obj->$method(...)> line.

For example, this will print the message C<Check why...>
and stop at the method call:

  [
    ...

    'Check why foo returns 2 instead of 3',

    [
      [ qw( frobnicate foo ) ],
      [ 3 ],
    ]
  ],

=head1 EXAMPLES

  my @testz =
  (
    # evaluate expected failures

    # modify is expected to fail, but the empty
    # arrayref is a signal that nothing is expected
    # back from the test.

    [
      [],
      [ modify => ( label => $field2, 'xyz' ) ],
    ],

    # false label shouldn't change anything

    [
      [],                                         # expect failure
      [ modify => ( label => $field2, ''    ) ],
    ],

    [
      [ qw( ijk                             ) ],  # expect return of 'ijk'
      [ lookup => ( label => $field2        ) ],
    ],

    [
      [],                                         # expect failure
      [ modify => ( label => $field2, 0     ) ],
    ],

    [
      [ qw( ijk                             ) ],  # expect string 'ijk' again
      [ lookup => ( label => $field2        ) ],
    ],

  );

Gives output:

  ok 10 - lookup label f.10e => ijk
  Bogus label: field label 'xyz' used by 'f.10d'
  ok 11 - modify label f.10e xyz => expected exception
  Bogus modify label: false label '' (f.10e)
  ok 12 - modify label f.10e  => expected exception
  Bogus modify label: false label '0' (f.10e)


=head1 DEBUG

Re-run a failed operation:

  $ perl -d ./t/some-test.t;

  ok ...
  ok ...
  ok ...

  ...

  Failed execution:
  <failure message>

  47:       0
    DB<1> &$cmd

  CM::TxDB::Metadata::t::Harness::CODE(0x8ada248)(/home/slembark/sandbox/Cheetahmail/spot/branches/dev_1_0_0/lib/CM/TxDB/Metadata/t/Harness.pm:184):
  184:              $obj->$method( @argz )
    DB<<2>> s


The tests can also be run in benchmark mode via:

  BENCHMARK=1 perl t/foo.t;

which will skip loading Test::More and run the
operations via:

  eval { $obj->$method( @$argz ) }

timing the entire exeuction via benchmark.

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

=head1 COPYRIGHT

Copyright (C) 2007 Steven Lembark.
This code is released under the same terms as Perl-5.8.
