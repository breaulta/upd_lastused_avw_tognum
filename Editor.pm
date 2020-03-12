package Editor;

use strict;
use warnings;

# Hash to map cell letters to the corresponding numbers used by gnumeric spreadsheet.
my %letters = (
	A => 0, B => 1, C => 2, D => 3, E => 4, F => 5, G => 6, H => 7, I => 8, J => 9,
	K => 10, L => 11, M => 12, N => 13, O => 14, P => 15, Q => 16,
);
my $temp_file = "current_working_temp_file";

sub new {
	my ($class, $filename) = @_;
	die "Specified file $filename doesn't appear to be a gnumeric spreadsheet"
		unless $filename =~ /.+\.gnumeric$/;
	die "Specified file $filename doesn't exist!"
		unless -e $filename;
	#https://perldoc.perl.org/functions/bless.html
	#Instantiates the Class into the Object?
	my $self = bless { 
		filename => $filename, 
	}, $class;
	my $gnumeric_ss = $filename;
	#
	$gnumeric_ss =~ /(.+)\.gnumeric$/;
	my $ss = $1;
	my $gz_ss = "$1.gz";
	#Convert file to type that is useable by perl.
	#The constructor creates a temp file that is useable by perl and persists until (presumably) the object is deconstructed.
	system("cp", $gnumeric_ss, $gz_ss) == 0 or die "System call failed: $?";
	system("gunzip", $gz_ss) == 0 or die "System call failed: $?";
	system("mv", $ss, $temp_file) == 0 or die "System call failed: $?";

	return $self;
}

#Leaving this unneeded sub for reference for now.
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
	my $data;

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
	open( my $fh, "<", $temp_file) or die "Can't open $temp_file: $!";
	#	Read in contents in form that can be regex'd
	while( my $line = <$fh> ){
		#print $line;
		#	Loop through lines until <gnm:Cell Row="2" Col="1" ValueType="60">Number</gnm:Cell> is found.
		#if( $line =~ /<gnm:Cell Row=\"$row\" Col=\"$column\" ValueType=\"\d+\">(\w+)<\/gnm\:Cell>/ ){
		if( $line =~ /\<gnm\:Cell Row\=\"$row\" Col\=\"$column\" ValueType\=\"\d+\"\>(.+)\<\/gnm\:Cell\>/g ){
			$data = $1;
			print "data: $data\n";
		}
	}
	return $data;
	#	Read contents
	#	Return contents	

}

sub writecell {

}

1;
