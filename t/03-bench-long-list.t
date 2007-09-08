use strict;

use Test::More qw( tests 1 );

use Object::Exercise qw( -b );

my @testz = ();

my @keyz    = ( 'a' .. 'z' );

my %valz    = ();

for( 1 .. 10_000 )
{
    my $key = $keyz[ rand @keyz ];

    my $val = 1 + int rand 100;

    if( int rand 2 )
    {
        $valz{ $key } = $val;

        push @testz,
        [
            [ set => $key, $val ],
            [ $val              ],
            "Set $key => $val"
        ];
    }
    else
    {
        my $show = exists $valz{ $key } ? $valz{ $key } : '';

        push @testz,
        [
            [ get => $key   ],
            [ $valz{ $key } ],
            "Get $key == $show"
        ];
    }
}

$benchmark->( t::Frobnicate->new, @testz );

pass "Benchmark complete";

package t::Frobnicate;

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
