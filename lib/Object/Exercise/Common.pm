# $Id$
#######################################################################
# housekeeping
#######################################################################

package Object::Exercise::Common;

require 5.6.2;

use strict;

use IO::Handle;
use Data::Dumper;
use Symbol qw( qualify_to_ref );

########################################################################
# package variables
########################################################################

our $VERSION = 1.00;

########################################################################
# utility subs & variables shared among Object::Execute & friends.

my %exportz =
(
    log_message => 
    sub
    {
        # note that re-opening STDERR will re-direct the commant.
        # there usually aren't enough log messages to make the
        # {IO} operation significant over the execution.

        local $Data::Dumper::Purity     = 0;
        local $Data::Dumper::Terse      = 1;
        local $Data::Dumper::Indent     = 1;
        local $Data::Dumper::Deparse    = 1;
        local $Data::Dumper::Sortkeys   = 1;
        local $Data::Dumper::Deepcopy   = 0;
        local $Data::Dumper::Quotekeys  = 0;

        local $, = "\n";
        local $\ = "\n";

        *STDERR{ IO }->printflush( map { ref $_ ? Dumper $_ : $_ } @_ );

        ()
    },

    # these are set in Exercise::import, used in 
    # Execute & Benchmark.

    continue => \( my $a = '' ),
    verbose  => \( my $b = '' ),
);

sub import
{
    my $caller  = caller;
    my $package = __PACKAGE__;

    shift if $_[0] eq $package;

    warn "Bogus $package: no arguments" unless @_;

    for( @_ )
    {
        my $export  = $exportz{ $_ }
        or die "Bogus $package: unknown export '$_'";

        my $ref     = qualify_to_ref $_, $caller;

        # install as ref to subref, which avoids installing
        # this as a subroutine, its a scalar subref in the caller.

        *$ref
        = 'CODE' eq ref $export
        ? \$export
        : $export
        ;
    }

    1
}

# keep require happy

1

__END__
