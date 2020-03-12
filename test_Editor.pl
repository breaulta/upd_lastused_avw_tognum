#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/lubuntu/proj';
use Editor;

my $editor = new Editor('sample_spreadsheet.gnumeric');

#$editor->openfile('sample_spreadsheet.gnumeric');
#$editor->openfile();
my $read = $editor->readcell('k3');
print "Readcell returns: $read\n";

