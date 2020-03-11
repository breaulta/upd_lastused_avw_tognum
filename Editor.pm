package Editor;

use strict;
use warnings;

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

}

sub writecell {

}

1;
