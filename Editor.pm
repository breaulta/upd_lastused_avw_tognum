package Editor;

use strict;
use warnings;

# Hash to map cell letters to numbers used in the spreadsheet.
my %letters = (
	A => 0, B => 1, C => 2, D => 3, E => 4, F => 5, G => 6, H => 7, I => 8, J => 9,
	K => 10, L => 11, M => 12, N => 13, O => 14, P => 15, Q => 16,
);

sub new {	#Need to check with Len if this is the proper way to do this.
	#my $class = shift;
	#my $self = {};
	#bless $self, $class;
	#return $self;
	my ($class, $filename) = @_;
	die "A gnumeric spreadsheet file is required for this constructor." if $filename eq "";
	my $self = bless { file => $filename, }, $class;
	return $self;
}

sub openfile {
	my $self = shift;
	my $gnumeric_ss = $self->{file};

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
	
	#Split letter from number
	$cell =~ /(\w)(\d+)/;
	my $column = uc $1;	#Set everything to uppercase.
	my $row = $2;
	print "Reading user input- Col:$column, Row:$row\n";

	#Dereference letter to number using %letters, rows start at 0 instead of 1.
	$column = $letters{$column};
	$row--;
	print "Type used by gnumeric- Col:$column, Row:$row\n";

	#Find line that corresponds to cell
	#	open file associated with this object
	#	Read in contents in form that can be regex'd
	#	Loop through lines until <gnm:Cell Row="2" Col="1" ValueType="60">Number</gnm:Cell> is found.
	#	Read contents
	#	Return contents	

}

sub writecell {

}

1;
