#!/usr/bin/perl
use warnings;
use strict;

use WWW::Mechanize;

my $base_url = 'https://www.airvoicewireless.com';
my $username = 'YOUR E-MAIL HERE';

#Get password.
system ("stty", "-echo");
print "Enter password: \n";
my $password = <>;
system ("stty", "sane");
chomp $password;

#Login to account.
my $mech = WWW::Mechanize->new();
$mech->get($base_url . "/login");
$mech->submit_form(
	form_id => 'login-form',
	#form_number => 1,
	fields      => {
		form      => 'login',
		email     => $username,
		password  => $password,
	}
);

#Determine account number.
die "Cannot find account number!" unless $mech->text() =~ m/Your associated account\(s\) are: (\d+)/;
my $account_number = $1;

#Fetch call details text.
$mech->get($base_url . "/my-account/call-details?a=" . $account_number);
my $call_details = $mech->content( decoded_by_headers => 1 );
open (my $call_file, ">", "call_details.html");
print $call_file $call_details;
close $call_file;

#Fetch account profile text.
$mech->get($base_url . "/my-account/account-profile?a=" . $account_number);
my $account_profile = $mech->content( decoded_by_headers => 1 );
open (my $profile_file, ">", "account_profile.html");
print $profile_file $account_profile;
close $profile_file;


#WORKS!

=comment
Returned html source in 2.html:
href="/my-account/account-profile?a=1917166">Account Profile</a></div>
href="/my-account/call-details?a=1917166">Call Details
=cut


