
use strict;

use Object::Exercise;

my $frob = Frobnicate->new;

my @testz =
(
    [ [ qw( set foo bar ) ], [ qw( bar ) ]  ],
    [ [ qw( get foo     ) ], [ qw( bar ) ]  ],

    'break',

    [ [ qw( set foo     ) ], [ qw( bar ) ]  ], 
    [ [ qw( get foo     ) ], [ undef     ]  ],

);

$frob->$exercise( @testz );

package Frobnicate;

use strict;

sub new
{
    my $proto = shift;

    bless {}, ref $proto || $proto
}

sub set
{
    my ( $obj, $key, $value ) = @_;

    @_ > 2
    ? $obj->{ $key } = $value
    : delete $obj->{ $key }
}

sub get
{
    my ( $obj, $key ) = @_;

    $obj->{ $key }
}

__END__
