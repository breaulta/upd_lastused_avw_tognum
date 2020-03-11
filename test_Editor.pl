#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/lubuntu/proj';
use Editor;

my $editor = new Editor();

$editor->openfile('sample_spreadsheet.gnumeric');
