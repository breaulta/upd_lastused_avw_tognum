#!/usr/bin/perl
use warnings;
use strict;

#Convert Gnumeric cell date number to m/d/yyyy format, and back again.

#Apparently spreadsheets measure dates by an integer count, where the epoch is December 30, 1899. The history behind this decision found here: https://tinyurl.com/utube75

use Date::Calc qw(:all);

my $ss_epoch_year = 1899;
my $ss_epoch_month = 12;
my $ss_epoch_day = 30;

#Prints "3/12/2020" for sample Gnumeric cell date/day integer "43902".
print ss_num_to_date("43902"), "\n";

#Prints "43903" for given date "3/13/2020".
print ss_date_to_num("3/13/2020"), "\n";


sub ss_num_to_date {
	my $num = shift;
	#Number must be an integer.
	die "Invalid spreadsheet date number" unless $num =~ m/^\d+$/;
	my ($year,$month,$day) = Add_Delta_Days($ss_epoch_year,$ss_epoch_month,$ss_epoch_day,$num);
	return "$month/$day/$year";

}

sub ss_date_to_num {
	my $date = shift;
	#Date must be in m/d/yyyy format.
	die "Invalid m/d/yyyy format" unless $date =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
	my ($month, $day, $year) = ($1, $2, $3);
	return Delta_Days($ss_epoch_year,$ss_epoch_month,$ss_epoch_day,$year,$month,$day);	
}
