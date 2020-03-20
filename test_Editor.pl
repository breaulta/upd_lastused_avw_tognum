#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/lubuntu/proj';
use Editor;

my $editor = new Editor('sample_spreadsheet.gnumeric');

my $cell = 'b5';
my $data = 'test';

#$editor->openfile('sample_spreadsheet.gnumeric');
#$editor->openfile();
my $read = $editor->readcell($cell);
print "Readcell returns: $read\n";
$editor->writecell($cell, $data);
print "Attempting to write cell $cell with data:$data\n";
$read = $editor->readcell($cell);
print "Read after write returns: $read\n";
