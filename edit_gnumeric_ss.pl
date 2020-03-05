#!/usr/bin/perl

use strict;
use warnings;

my $gnumeric_ss = "sample_spreadsheet.gnumeric";
my $gz_ss = "sample_spreadsheet.gz";
my $ss = "sample_spreadsheet";

#Will need to regex match the filename here for the .gnumeric to .gz swap
rename $gnumeric_ss, $gz_ss;
system("gunzip", $gz_ss) == 0 or die "system call failed: $?";
system("cp", $ss, "copyof_sample_spreadsheet");

#cleanup
system("gzip", $ss) == 0 or die "system call failed: $?";
system("mv", $gz_ss, $gnumeric_ss) == 0 or die "system call failed: $?";
