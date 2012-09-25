package PICA::Modification::Request;
{
  $PICA::Modification::Request::VERSION = '0.134';
}
#ABSTRACT: Request for modification of an identified PICA+ record

use strict;
use warnings;
use v5.10;

use parent 'PICA::Modification';
use Time::Stamp gmstamp => { format => 'easy', tz => '' };
use Scalar::Util qw(blessed);

our @ATTRIBUTES = qw(id iln epn del add request creator status updated created);


sub new {
	my $class = shift;
	my $attributes = @_ % 2 ?  (blessed $_[0] ? $_[0]->attributes : {%{$_[0]}}) : {@_};

    my $self = bless { 
		map { $_ => $attributes->{$_} 
	} @ATTRIBUTES }, $class;

	$self->{status} //= 0;
	$self->{created} //= gmstamp;

	$self->check;
}


sub attributes {
	my $self = shift;

	return { map { $_ => $self->{$_} } @ATTRIBUTES };
}


sub update {
	my ($self,$status) = @_;

	$self->{status}  = $status;
	$self->{updated} = gmstamp;
}

1;

__END__
=pod

=encoding utf-8

=cut

