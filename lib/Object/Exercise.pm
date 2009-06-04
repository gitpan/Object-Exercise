# $Id: Exercise.pm 266 2009-06-04 13:48:25Z lembark $
#######################################################################
# housekeeping
#######################################################################

package Object::Exercise;

require 5.6.2; # I'm running 5.8.8; hopefully this is reasonable...

use strict;

use Symbol qw( qualify_to_ref );

use Object::Exercise::Common qw( log_message continue verbose );

########################################################################
# package variables
########################################################################

our $VERSION = 1.02;

########################################################################
# subroutines
########################################################################

sub import
{
    my $package = __PACKAGE__;
    my $caller  = caller;

    # discard the class argument.

    shift if $_[0] eq $package;

    # arguments:
    # -k turns off fatal on error.
    # -v turns on  verbose.
    # -b uses benchmark instead of execution handler.
    # -e uses execution handler (default).
    # -n specifies the installed name (vs. 'execution' or 'benchmark'.
    # -p turns off plannng in the test loop.

    my %exportz = ();

    while( @_ )
    {
        my $arg = shift;

        if( $arg =~ /^-k/ )
        {
            $continue = 1;
        }
        elsif( $arg =~ /^-v/ )
        {
            $verbose = 1;
        }
        elsif( $arg =~ /^-b/ )
        {
            my $name = ( index $_[0], '-' ) ? 'benchmark' : shift ;

            $exportz{ benchmark } = $name;
        }
        elsif( $arg =~ /^-e/ )
        {
            my $name = ( index $_[0], '-' ) ? 'execute' : shift ;

            $exportz{ execute } = $name;
        }
        else
        {
            die "Bogus $package: unknown switch '$arg'";
        }
    }

    %exportz = qw( execute exercise ) unless %exportz;

    while( my($src,$dst) = each %exportz )
    {
        $log_message->( "$package installing '$src' into '$caller' as '$dst'" )
        if $verbose;

        my $module  = $package . '::' . ucfirst $src;

        my $handler = eval "require $module";

        my $ref     = qualify_to_ref $dst, $caller;

        *$ref       = \$handler;
    }

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

  $exercise->( $object, @test_opz );        # $object->method( @argz )


=head1 DESCRIPTION

This package exports a single subroutine , C<$exercise>, which
functions as an OO execution loop (see '-n' for changing the 
installed name).

C<$execute> is a subroutine reference that takes an object
and set of operations. The first element in that list
is an object of the class being tested. The remaining
elements are a list of operations, each of which is an
array reference.

Each operation consists of a method call and the method's arguments. Each
method call is dispatched using the object, optionally comparing the return
value to some pre-defined result.

Exceptions are trapped and logged. The last operation can be re-executed if
it fails.

All operations are passed in as arrayrefs. They can be nested either to store
a return value and test to run, or to hold a list consisting of a method name
and its arguments.

=head2 Arguments for "use Object::Exercise"

=over 4

=item -e [yourname]

Default is to install '$execute' to run operations,
testing for $@, and comparing return values with cmp_deeply.

The optional 'yourname' can provide an alternate name
to '$execute'.

=item -b [yourname]

Alternative is to intall '$benchmark' with counts the
operations and errors (via $@), and reports the total
elapsed time, operations, and errors.

The optional 'yourname' can provide an alternate name
to '$benchmark'.

=item -v 

Turn on verbose reporting of results in execution mode
and report the symbols exported, largely equivalent to
adding 'verbose' before any arrayrefs.

=item -k 

Assume failures are expected and ignore them for logging
and breakpoints. Equivalent to adding 'continue' before 
any arrayrefs (i.e., as with "make -k").

=item Notes

If neither -e nor -b is used then the default is to supply
'$execute'.

If both -e and -b are used then both will be exported.

=back

=head1 Exercising Objects

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
say to a utility function that does some extra data checking,
logging, or updates the module. These are especially useful
for updating the object state during execution.

=head2 Re-Running Failed Operations

Operations are deemed to fail if they raise an
exception (I<i.e.>, C<$@> is set at their completion) or if
the return value does not compare deeply to expected
data (if provided).

In either case, it is often helpful to examine the
failed operation. This is accomplished here by
wrapping each exectution in a closure:

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

=head3 Messages

Sometimes it's reassuring to know progress is being
make (or it's helpful to keep a log of what happend).

Non-referent entries in the test list that aren't 
recognized are simply printed:

    ...

    "Updating based on $computed value...",

    [
        [ foobar  => $computed_value ],
        ...
    ]

    "... Finished Computed value update.",

will sandwich a method call between two messages.

=head3 Breakpoints

It is sometimes helpful to stop the execution of code
before it fails in order to examine its execution before
the failure. The "debug" directive will set the breakpoint
before the first method call. This will leave you at
$obj->$method( @argz ) (see below under DEBUGGING).

The 'debug' directive can be aliased as 'break'.

For example, this will run up to the point where 
"frobnicate" is about to be called and then stop:

  [
    ...

    'break',

    [
      [ qw( frobnicate foo ) ],
      [ 3 ],
    ]

    'nobreak',
  ],

Until "nodebug" or "nobreak" is used after this, all calls
will hit the breakpoint. Using an expect value of '' turns
on continue mode for one operation (e.g., for testing 
proper handling of failure cases):

    [
        [ qw( this_fails ) ],
        ''
    ],

is equivalent to:

    'continue',

    [
        [ qw( this_fails        ) ],
        [ qw( expect failure    ) ],
    ],

    'nocontinue',

=head3 Turning off comparison breakpoints.

Normal behavior for Object::Exercise is to abort the
execution plan when the first $@ or cmp_deeply failure
is encountered. The behavior can be changed to continue
execution via the "continue" directive (or set via the
"-k" switch when the module is used). Inserting "nocontinue"
will turn back on the normal behavior.

This can be helpful when initial operations need to clean
up before starting: failures can be ignored until some
set of sanity checks.

    ...
    'continue',

    [ cleanup that may fail.  ],
    [ cleanup that may fail.  ],

    'nocontinue',

    [ sanity check ]

Execution will log any failures through the "nocontinue"
line as expected failures, something like:

  ok 1 - modify label field_x xyz => xyz
  ok 2 - lookup label field_x => xyz
* ok 3 - modify label field_x => expected exception
  ok 4 - lookup label field_x => xyz

=head1 DEBUGGING FAILED OPERATIONS

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

  Metadata::t::Harness::CODE(0x8ada248):
  184:              $obj->$method( @argz )
    DB<<2>> s

At this point you will be at the first line of $method
(given sub or coderef location). The failure message 
will show up for $@ set after calling the method or
if cmp_deeply finds a discrepency in the result.


=head1 EXAMPLES

    my $field2 = 'field_x';
  

    my @opz =
    (
        # evaluate expected failures

        # modify is expected to fail, but the empty
        # arrayref is a signal that nothing is expected
        # back from the test.

        [
            [ drop =>   ( $field_2 ) ],                 # pre-cleanup
            ''                                          # ignore failre
        ],

        [
            [ write =>  ( label => $field2, 'xyz' ) ],
            [ 'xyz'                                 ],  # expect 'xyz'
        ],

        [
            [ read =>   ( label => $field2 )        ],
            [ qw( xyz )                             ],  # expect 'xyz'
        ],

        [
            [ write =>  ( label => $field2, '' )    ],  # invalid argument: 
            '',                                         # expect failure
        ],

        [
            [ read =>   ( label => $field2 )        ],
            [ qw( xyz )                             ],  # expect 'xyz'
        ],

    );

    $execute->( $object, @opz );


=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

=head1 COPYRIGHT

Copyright (C) 2007 Steven Lembark.
This code is released under the same terms as Perl-5.8.

