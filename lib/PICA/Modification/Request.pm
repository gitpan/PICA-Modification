package PICA::Modification::Request;
{
  $PICA::Modification::Request::VERSION = '0.14';
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

=head1 NAME

PICA::Modification::Request - Request for modification of an identified PICA+ record

=head1 VERSION

version 0.14

=head1 DESCRIPTION

PICA::Modification::Request models a request for modification of an identified
PICA+ record. This class extends PICA::Modification with the following
attributes:

=over 4

=item request

A unique identifier of the request.

=item creator

An optional string to identify the creator of the request.

=item status

The modification requests's status which is one of 0 for unprocessed, 1 for
processed or solved, and -1 for failed or rejected.

=item updated

Timestamp when the modification request was last updated or checked.

=item created

A timestamp when the modification request was created.

=back

All timestamps are GMT with format C<YYYY-MM-DD HH:MM::SS>.

=head1 METHODS

=head2 attributes

Returns a hash reference with attributes of this modification request (del,
add, id, iln, epn, request, creator, status, updated, created).

=head2 update ( $status )

=encoding utf-8

=head1 AUTHOR

Jakob Voß <voss@gbv.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

