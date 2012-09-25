package PICA::Modification;
{
  $PICA::Modification::VERSION = '0.134';
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

    if ($self->{add}) {
        my $pica = eval { PICA::Record->new( $self->{add} ) };
        if ($pica) {
			$self->error( iln => 'missing ILN for add' )
				if !$self->{iln} and $pica->field(qr/^1/);
			$self->error( epn => 'missing EPN for add' )
				if !$self->{epn} and $pica->field(qr/^2/);
            $pica->sort;
	    	$self->{add} = "$pica";
			chomp $self->{add};
        } else {
            $self->error( add => "malformed fields to add" );
        }
    }

	my @del = sort grep { $_ !~ /^\s*$/ } split(/\s*,\s*/, $self->{del});

	$self->error( del => "malformed fields to remove" )
        if grep { $_ !~  qr{^[012]\d\d[A-Z@](/\d\d)?$} } @del;

	$self->error( epn => 'missing EPN for remove' )
		if !$self->{epn} and grep { /^2/ } @del;
	$self->error( iln => 'missing ILN for remove' )
		if !$self->{iln} and grep { /^1/ } @del;

    $self->{del} = join (',', @del);

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

=encoding utf-8

=cut

