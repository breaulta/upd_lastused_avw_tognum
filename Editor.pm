package Editor;

use strict;
use warnings;

# Hash to map cell letters to numbers used in the spreadsheet.
my %letters = (
	A => 0, B => 1, C => 2, D => 3, E => 4, F => 4, G => 4, H => 4, I => 4, J => 4,
	K => 4, L => 4, M => 4, N => 4, O => 4, P => 4, Q => 4,
);

sub new {	#Need to check with Len if this is the proper way to do this.
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}

sub openfile {
	my $self = shift;
	my $gnumeric_ss = shift;

	#Use regex so code is applicable to any filename.
	$gnumeric_ss =~ /(.+)\.gnumeric$/;
	my $ss = $1;
	my $gz_ss = "$1.gz";

	#Convert file to type that is useable by perl.
	rename $gnumeric_ss, $gz_ss;
	system("gunzip", $gz_ss) == 0 or die "System call failed: $?";
	system("cp", $ss, "copyof_sample_spreadsheet");

	#cleanup
	system("gzip", $ss) == 0 or die "System call failed: $?";
	system("mv", $gz_ss, $gnumeric_ss) == 0 or die "System call failed: $?";
	#'copyof_spreadsheet' file not cleaned up for now for testing.
}

sub savefile {

}

sub readcell {
	my $self = shift;
	my $cell = shift;

	#B3 translates to Row="2" Col="1"
	#<gnm:Cell Row="2" Col="1" ValueType="60">Number</gnm:Cell>
	print $letters{A};

}

sub writecell {

}

1;
