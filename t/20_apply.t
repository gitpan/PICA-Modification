use strict;
use warnings;
use v5.10;
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

$e = picamod( iln => 20, add => '144Z $all', del => '144Z', id => 'abc:ppn:123' );
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

## level 2

#$e = picamod( epn => '123', add => '201A $afoo', id => 'abc:ppn:123' );
#$e->apply( $p1, strict => 1 );
#is( $e->error('iln'), 'ILN missing', 'EPN requires ILN' );


my @tests = (
  {
    about => 'added level 1 field only to one holding',
    id => 'abc:ppn:123', iln => 50, del => '144Z', add => '144Z $all',
    pica  => <<'PICA',
003@ $0123
021A $aHello
101@ $a20$cPICA
101@ $a50$cPICA
PICA
    expect => <<'PICA',
003@ $0123
021A $aHello
101@ $a20$cPICA
101@ $a50$cPICA
144Z $all
PICA
  },{
    about => 'removed level 1 field',
    id => 'abc:ppn:123', iln => 20, del => '144Z', 
    pica  => <<'PICA',
003@ $0123
021A $aHello
101@ $a20$cPICA
144Z $all
101@ $a50$cPICA
144Z $axx
PICA
    expect => <<'PICA',
003@ $0123
021A $aHello
101@ $a20$cPICA
101@ $a50$cPICA
144Z $axx
PICA
 },{
    about => 'modified level 0 field',
    id => 'abc:ppn:123', iln => 50, del => '011@', add => '011@ $a2003',
    pica  => <<'PICA',
003@ $0123
021A $aTest
011@ $a1999
101@ $a50
203@/01 $0123
203@/02 $0456
PICA
    expect => <<'PICA',
003@ $0123
011@ $a2003
021A $aTest
101@ $a50
203@/01 $0123
203@/02 $0456
PICA
  }
);

foreach my $test (@tests) {
    my $pica   = picarec(delete $test->{pica});
    my $expect = picarec(delete $test->{expect});
    my $about  = delete $test->{about};
    my $got    = picamod( %$test )->apply( $pica, strict => 1 );
    is "$got", "$expect", $about;
}

done_testing;
