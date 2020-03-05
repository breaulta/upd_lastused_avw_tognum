#!/usr/bin/perl

use strict;
use warnings;

#hardcoded for now; will change later
my $gnumeric_ss = "sample_spreadsheet.gnumeric";
#Use regex so code is applicable to any filename.
$gnumeric_ss =~ /(.+)\.gnumeric$/;
my $ss = $1;
my $gz_ss = "$1.gz";

#Will need to regex match the filename here for the .gnumeric to .gz swap
rename $gnumeric_ss, $gz_ss;
system("gunzip", $gz_ss) == 0 or die "system call failed: $?";
system("cp", $ss, "copyof_sample_spreadsheet");

#cleanup
system("gzip", $ss) == 0 or die "system call failed: $?";
system("mv", $gz_ss, $gnumeric_ss) == 0 or die "system call failed: $?";
