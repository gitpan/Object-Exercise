# $Id: Exercise.pm 47 2007-06-04 15:22:42Z lembark $
#######################################################################
# housekeeping
#######################################################################

package Object::Exercise::Execute;

require 5.6.2;

use strict;
use Test::More;
use Test::Deep qw( cmp_deeply  );

use Object::Exercise::Common qw( log_message continue verbose );

########################################################################
# package variables
########################################################################

our $VERSION = 1.00;

# use to control breakpoints within the loop.
# our necessary to permit use of local.

our $debug      = '';

# handle iterations: verbose controls reporting, 
# continue ignores errors in the eval of a command. 

my $noplan      = '';

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
    [ qw( nobreak   nodebug     ) ],
)
{
    my( $alias, $existing ) = @$_;

    $parmz{ $alias } = $parmz{ $existing }
    and next;

    die "Invalid alias '$alias' for unknown '$existing'"
}

########################################################################
# local utility subs
########################################################################

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

# generate a closure from a command, method, and args.

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
# handle one element of the execution list.
########################################################################

my %ref_handlerz =
(
    ARRAY =>
    sub
    {
        use Scalar::Util qw( reftype );

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

        if
        (
            1 <= @$element
            &&
            'ARRAY' eq reftype $element->[0]
        )
        {
            no warnings;

            ( $argz, $expect, $message ) = @$element;

            $compare    = 1;

            $message ||= join ' ', @$argz, '->', @$expect;
        }
        else
        {
            no warnings;

            @$argz = @$element;

            $message = join ' ', @$argz;
        }

        my $cmd     = $gen_command->( $obj, $argz );

        my $result  = eval { [ &$cmd ] };

        if( $@ )
        {
            if( $continue || $expect eq '' )
            {
                pass "Expected failure: $message" unless $noplan;
            }
            else
            {
                fail "Unexpected failure: $message" unless $noplan;

                $handle_error->( "Failed execute: $message", $cmd );
            }
        }
        elsif( $compare )
        {
            cmp_deeply $result, $expect, $message
            and return;

            fail "Failed compare: $message" unless $noplan;

            $handle_error->
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
# exported to caller 

sub
{

    # no reason to look this up in the symbol table every
    # time, it won't change.

    my $obj     = shift;

    my $count   = 0;

    unless( $noplan )
    {
        $count
        = grep
        {
            (ref $_)              # ignore breaks
            &&
            (ref $_ eq q{ARRAY})  # check for array
            &&
            (ref $_->[0])         # test in initial location
        }
        @_;

        if( $count )
        {
            plan tests => $count;

            $log_message->( "Executing: $count tests" )
            if $verbose;
        }
        else
        {
            plan tests => 1;
        }
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

    if( $noplan )
    {
        $log_message->( "Execution complete" )
        if $verbose;
    }
    else
    {
        $count or pass "Execution complete";
    }
}

__END__
