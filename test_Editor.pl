#!/usr/bin/perl

use strict;
use warnings;

# Required for linux.
use lib '/home/lubuntu/proj';
use Editor;

my $editor = new Editor('sample_spreadsheet.gnumeric');

my $cell = 'k5';
my $data = '12/20/1988';
my $filename = 'test_savefile.gnumeric';

#$editor->openfile('sample_spreadsheet.gnumeric');
#$editor->openfile();
my $read = $editor->readcell($cell);
#print "Readcell returns: $read\n";
#$editor->writecell($cell, $data);
#print "Attempting to write cell $cell with data:$data\n";
#$read = $editor->readcell($cell);
#print "Read after write returns: $read\n";
$editor->writecell('a4', 'This');
$read = $editor->readcell('a4');
print "Read after write returns: $read\n\n";
$editor->writecell('b4', 'is');
$read = $editor->readcell('b4');
print "Read after write returns: $read\n\n";
$editor->writecell('c4', 'an');
$read = $editor->readcell('c4');
print "Read after write returns: $read\n\n";
$editor->writecell('d4', 'example');
$read = $editor->readcell('d4');
print "Read after write returns: $read\n\n";
$editor->writecell('e4', 'of a');
$read = $editor->readcell('e4');
print "Read after write returns: $read\n\n";
$editor->writecell('f4', 'successful');
$read = $editor->readcell('f4');
print "Read after write returns: $read\n\n";
$editor->writecell('g4', 'test');
$read = $editor->readcell('g4');
print "Read after write returns: $read\n\n";
$editor->writecell('h4', 'on');
$read = $editor->readcell('h4');
print "Read after write returns: $read\n\n";
$editor->writecell('i4', 'this');
$read = $editor->readcell('i4');
print "Read after write returns: $read\n\n";
$editor->writecell('j4', 'date:');
$read = $editor->readcell('j4');
print "Read after write returns: $read\n\n";
$editor->writecell('k4', '03/20/2020');
$read = $editor->readcell('k4');
print "Read after write returns: $read\n\n";
$editor->savefile($filename);
