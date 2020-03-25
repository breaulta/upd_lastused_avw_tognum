#!/usr/bin/perl
use warnings;
use strict;

use WWW::Mechanize;

my $base_url = 'https://www.airvoicewireless.com';
my $username = 'aaronbreault@gmail.com';
print "Using email: $username\n";

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
print "Found account number => Successfully logged into system!\n";

my $saved_call_details = "call_details.html";
#Fetch call details text.
$mech->get($base_url . "/my-account/call-details?a=" . $account_number);
my $call_details = $mech->content( decoded_by_headers => 1 );
open (my $call_file, ">", $saved_call_details) or die "Can't open $saved_call_details: $!";
print $call_file $call_details;
close $call_file;
# Use regex to find in call_details.html:
#	Last call date (either incoming or outgoing) from Call Records
#	Last text date (OUTGOING ONLY) from SMS Records
#	Last data use date from Data Records.
# Hash to store call details.
my %last_call_details = (
	call => '',
	text => '',
	data => '',
);
open( my $call_fh, "<", $saved_call_details) or die "Can't open $saved_call_details: $!";
while( <$call_fh> ){

}	

sleep(1);	#Sleep 1 second as to not get flagged for ddos.
my $saved_account_profile = "account_profile.html";
#Fetch account profile text.
$mech->get($base_url . "/my-account/account-information?a=" . $account_number);
my $account_profile = $mech->content( decoded_by_headers => 1 );
open (my $profile_file, ">", $saved_account_profile);
print $profile_file $account_profile;
close $profile_file;
# Use regex to find in account_profile.html
#	"Service Plan"
#	"Cash Balance"
#	"Airtime Exp Date"
#	"Data"
# Hash to store account data.
my %profile_data = (
	plan => '',
	balance => '',
	expires => '',
	data => '',
);


#WORKS!

=comment
Returned html source in 2.html:
href="/my-account/account-profile?a=1917166">Account Profile</a></div>
href="/my-account/call-details?a=1917166">Call Details
=cut


