use strict;
use warnings;
use Test::More;

use PICA::Record;
use PICA::Modification;

sub picamod { PICA::Modification->new(@_) }
sub picarec { PICA::Record->new(@_) }

my $e = picamod( del => '021A', add => '021A $aWorld', id => 'xy:ppn:1' );
my $p1 = picarec( '021A $aHello' );
my $p2 = picarec( '021A $aWorld' );

my $r = $e->apply( );
is( $e->error('id'), 'record not found', 'record required' );

$e->check;
is( $e->error('id'), undef, 'error cleaned' );

$r = $e->apply( $p1 );
ok( !$e->error, 'applied' );
is( "$r", "$p2", 'replaced field' );

$p1->ppn('123'); $p1->sort;
$p2->ppn('123'); $p2->sort;
$r = $e->apply( $p1, strict => 1 );
is( $e->error('id'), 'PPN does not match' );

$e = picamod( del => '021A', add => '021A $aWorld', id => 'abc:ppn:123' );
$r = $e->apply( $p1, strict => 1 );
is( "$r", "$p2", 'PPN match' );

## level 1

$e = picamod( iln => 20, add => '144Z $all', id => 'abc:ppn:123' );
$r = $e->apply( $p1 );
is ("$r", "$p1", "no modification" );

$r = $e->apply( $p1, strict => 1 );
is ($r, undef, 'level 1 not found' );
$e->check;

$p1->append( PICA::Field->new('101@ $a20$cPICA') );
$r = $e->apply( $p1, strict => 1 );
$p2 = picarec($p1);
$p2->append( PICA::Field->new('144Z $all') );
is "$r", "$p2", 'added level 1 field';

$p1->append( PICA::Field->new('101@ $a50$cPICA') );
$p2 = picarec($p1);
$p2->append( PICA::Field->new('144Z $all') );
$r = $e->apply( $p1, strict => 1 );
is "$r", "$p2", 'added level 1 field only to one holding';

$e = picamod( iln => 20, del => '144Z', id => 'abc:ppn:123' );
$r = $e->apply( $p1, strict => 1 );

$p2 = picarec(<<'PICA');
003@ $0123
021A $aHello
101@ $a20$cPICA
101@ $a50$cPICA
PICA
is "$r", "$p2", 'removed level 1 field';

## level 2

#$e = picamod( epn => '123', add => '201A $afoo', id => 'abc:ppn:123' );
#$e->apply( $p1, strict => 1 );
#is( $e->error('iln'), 'ILN missing', 'EPN requires ILN' );

done_testing;
