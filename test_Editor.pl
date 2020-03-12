#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/lubuntu/proj';
use Editor;

my $editor = new Editor('sample_spreadsheet.gnumeric');

#$editor->openfile('sample_spreadsheet.gnumeric');
#$editor->openfile();
$editor->readcell('f8');

