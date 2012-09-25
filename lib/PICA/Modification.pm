package PICA::Modification;
{
  $PICA::Modification::VERSION = '0.14';
}
#ABSTRACT: Modification of an identified PICA+ record

use strict;
use warnings;
use v5.10;

use PICA::Record;
use parent 'Exporter';


sub new {
	my ($class, %attributes) = @_;

    my $self = bless {
		map { $_ => $attributes{$_} } qw(id iln epn del add)
	}, $class;

	$self->check;
}


sub check {
	my $self = shift;

	$self->{errors} = { };

	foreach my $attr (qw(id iln epn del add)) {
		my $value = $self->{$attr} // '';
	    $value =~ s/^\s+|\s+$//g;
		$self->{$attr} = $value;
	}

	$self->{ppn} = '';
	$self->{dbkey} = '';
    if ($self->{id} =~ /^(([a-z]([a-z0-9-]?[a-z0-9]+))*):ppn:(\d+\d*[Xx]?)$/) {
        $self->{ppn}   = uc($4) if defined $4;
        $self->{dbkey} = lc($1) if defined $1;
    } elsif ($self->{id} eq '') {
        $self->error( id => 'missing record identifier' );
    } else {
        $self->error( id => 'malformed record identifier' );
    }

    $self->error( iln => "malformed ILN" ) unless $self->{iln} =~ /^\d*$/;
    $self->error( epn => "malformed EPN" ) unless $self->{epn} =~ /^\d*$/;

    my %must_delete;

    if ($self->{add}) {
        my $pica = eval { PICA::Record->new( $self->{add} ) };
        if ($pica) {
			$self->error( iln => 'missing ILN for add' )
				if !$self->{iln} and $pica->field(qr/^1/);
			$self->error( epn => 'missing EPN for add' )
				if !$self->{epn} and $pica->field(qr/^2/);
            $pica->sort;
            foreach ($pica->fields) {
                my $tag = $_->tag;
                # TODO: remove occurrence from level 2 tags
                $must_delete{$tag} = 1;
            }
	    	$self->{add} = "$pica";
			chomp $self->{add};
        } else {
            $self->error( add => "malformed fields to add" );
        }
    }

	my @del = grep { $_ !~ /^\s*$/ } split(/\s*,\s*/, $self->{del});

	$self->error( del => "malformed fields to remove" )
        if grep { $_ !~  qr{^[012]\d\d[A-Z@](/\d\d)?$} } @del;

	$self->error( epn => 'missing EPN for remove' )
		if !$self->{epn} and grep { /^2/ } @del;
	$self->error( iln => 'missing ILN for remove' )
		if !$self->{iln} and grep { /^1/ } @del;

    delete $must_delete{$_} for @del;
    if (%must_delete) {
        $self->error( del => 'fields to add must also be deleted' );
    }

    $self->{del} = join (',', sort @del);

    return $self;
}


sub attributes {
	my $self = shift;

	return {
		map { $_ => $self->{$_} } qw(id iln epn del add)
	};
}


sub error {
    my $self = shift;

    return (scalar keys %{$self->{errors}}) unless @_;
    
    my $attribute = shift;
    return $self->{errors}->{$attribute} unless @_;

    my $message = shift;
    $self->{errors}->{$attribute} = $message;

    return $message;
}


sub apply {
    my ($self, $pica, %args) = @_;
	my $strict = $args{strict};

    return if $self->error;

	if (!$pica) {
		$self->error( id => 'record not found' );
		return;
	} elsif ( $strict ) {
		if ( ($pica->ppn // '') ne $self->{ppn} ) {
			$self->error( id => 'PPN does not match' );
			return;
    	}

    	# TODO: check for disallowed fields to add/remove
	}

    my $iln = $self->{iln};
    my $epn = $self->{epn};

	# TODO: get ILN from record
	if ( $strict and $epn ne '' and $iln eq '' ) {
	    $self->error( iln => "ILN missing" );
		return;
	}

    my $add = PICA::Record->new( $self->{add} || '' );
    my $del = [ split ',', $self->{del} ];

    # new PICA record with all level0 fields but the ones to remove
    my @level0 = grep /^0/, @$del;
    my @level1 = grep /^1/, @$del;
    my @level2 = grep /^2/, @$del;

    # Level 0
    my $result = $pica->main;
    $result->remove( @level0 ) if @level0;
    $result->append( $add->main );    

    # Level 1
	if (@level1 or $add->field(qr/^1../)) {

		if ($strict and !$pica->holdings($iln)) {
			$self->error('iln', 'ILN not found');
			return;
		}

		foreach my $h ( $pica->holdings ) {
			if ($iln eq ($h->iln // '')) {
				$h->remove( map { $_ =~ qr{/} ? $_ : "$_/.." } @level1 );
				$h->append( $add->field(qr/^1/) );
			} 
			$result->append( $h->fields );
		}
	}

	# TODO: Level 2
	
    $result->sort;

    return $result;
}

1;



__END__
=pod

=head1 NAME

PICA::Modification - Modification of an identified PICA+ record

=head1 VERSION

version 0.14

=head1 DESCRIPTION

PICA::Modification models a modification of an identified PICA+ record
(L<PICA::Record>). The modification consist of the following attributes:

=over 4

=item add

A stringified PICA+ record with fields to be added.

=item del

A comma-separated list of PICA+ field tags to be removed. All tags of fields 
to be added must also be included for deletion so modifications are idempotent.

=item id

The fully qualified record identifier of form C<PREFIX:ppn:PPN>.

=item iln

The ILN of level 1 record to modify. Only required for modifications that
include level 1 fields.

=item epn

The EPN of the level 2 record to modify. Only required for modifications that
include level 2 fields.

=back

A modification instance may be malformed. A mapping from malformed attributes
to error messages is stored together with the PICA::Modification object.

=head1 METHODS

=head2 new ( %attributes )

Creates a new edit with given attributes. Missing attributes are set to the
empty string. On creation, all attributes are checked and normalized.

=head2 check

Checks and normalized all attributes. A list of error messages is collected,
each connected to the attribute that an error originates from.

=head2 attributes

Returns a hash reference with attributes of this modification (del, add, id,
iln, epn).

=head2 error( [ $attribute [ => $message ] ] )

Gets or sets an error message connected to an attribute. Without arguments this
method returns the number of errors.

=head2 apply ( $pica [, strict => 0|1 ] )

Applies the modification on a given PICA+ record and returns the resulting
record as L<PICA::Record> or C<undef> on malformed modifications. 

Only edits at level 0 and level 1 are supported by now.

The argument C<strict> can be used to enable additional validation. Validation
errors are also collected in the PICA::Modification object. A valid modification
must:

=over 4

=item *

have a record identifier with PPN equal to the record's PPN (or both have none)

=item *

have ILN/EPN matching to the record's ILN/EPN (if given).

=back

=head1 SEE ALSO

See L<PICA::Record> for information about PICA+ record format.

PICA::Modification is extended to L<PICA::Modification::Request>. Collections
of modifications can be stored in a L<PICA::Modification::Queue>.

To test additional implementations of queues, the unit testing package 
<PICA::Modification::TestQueue> should be used.

See L<PICA::Modification::App> for applications build on top of this module.

=encoding utf-8

=head1 AUTHOR

Jakob Voß <voss@gbv.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

