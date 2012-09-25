package PICA::Modification::Queue;
{
  $PICA::Modification::Queue::VERSION = '0.134';
}
#ABSTRACT: Queued list of modification requests on PICA+ records

use strict;
use warnings;
use v5.10;

use Carp;

sub new {
    my $class = shift;
    my $name  = shift || 'hash';
    
    $class = $class . '::' . ucfirst($name);

    my $file = $class;
    $file =~ s!::!/!g;
    require "$file.pm"; ## no critic

    $class->new( @_ );
}

1;


__END__
=pod

=encoding utf-8

=cut

