# $Id$
#######################################################################
# housekeeping
#######################################################################

package Object::Exercise::Benchmark;

require 5.6.2;

use strict;

use File::Basename;

use Benchmark qw( :hireswallclock );

use Object::Exercise::Common qw( log_message continue );

########################################################################
# package variables
########################################################################

our $VERSION = 1.00;

########################################################################
# exported to caller 

sub
{
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
}

__END__
