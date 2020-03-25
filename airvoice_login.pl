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
my $call_flag = 0;	# Off.
my $text_flag = 0;
my $data_flag = 0;
my $outgoing_flag = 0;
open( my $call_fh, "<", $saved_call_details) or die "Can't open $saved_call_details: $!";
while( <$call_fh> ){
	# Using an if-block filter to find datas.
	if( $outgoing_flag && /class\=\"cell date\"\>(.*)\</ ){
		# Grab the data in the line after 'Outgoing' was found.
		$last_call_details{'text'} = $1;
		$outgoing_flag = 0;
		$text_flag = 0;
		next;
	}elsif( !$call_flag && /Call Records/ ){
		# We've entered the Call Records section, we can now search for the first call.
		$call_flag = 1;
		next;
	}elsif( !$text_flag && /SMS Records/ ){
		# We've entered the SMS Records section, we can now search for the last outgoing text (find 'Outgoing').
		$text_flag = 1;
		next;
	}elsif( $text_flag && /Outgoing/ ){
		# Finding the first instance of Outgoing in the SMS section should make the very next line where our data is.
		$outgoing_flag = 1;
		next;
	}elsif( !$data_flag && /MMS Records/ ){
		# We've entered the SMS Records section, we can now search for the last outgoing text.
		$data_flag = 1;
		next;
	}elsif( $call_flag && /class\=\"cell date\"\>(.*)\</ ){
		$last_call_details{'call'} = $1;
		$call_flag = 0;	
		next;
	}elsif( $data_flag && /class\=\"cell date\"\>(.*)\</ ){
		$last_call_details{'data'} = $1;
		$data_flag = 0;	
	}
}
close $call_fh;
print "Results of processing $saved_call_details:\nlast call: $last_call_details{'call'}\nlast text: $last_call_details{'text'}\nlast data: $last_call_details{'data'}\n";

sleep(1);	#Sleep 1 second as to not get flagged for ddos.
my $saved_account_profile = "account_profile.html";
#Fetch account profile text.
$mech->get($base_url . "/my-account/account-information?a=" . $account_number);
my $account_profile = $mech->content( decoded_by_headers => 1 );
open (my $profile_file, ">", $saved_account_profile) or die "Can't open $saved_account_profile $!";
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
my $plan_flag = 0;	# Off.
my $balance_flag = 0;
my $expires_flag = 0;
$data_flag = 0;
open( my $profile_fh, "<", $saved_account_profile) or die "Can't open $saved_account_profile $!";
while( <$profile_fh> ){
	# Using an if-block filter to find datas.
	if( $plan_flag && /class\=\"blue\"\>(.*)\<\/span/ ){
		$profile_data{'plan'} = $1;
		$plan_flag = 0;
		next;
	}elsif( $balance_flag && /\<td\>\$(.*)\</ ){
		$profile_data{'balance'} = $1;
		$balance_flag = 0;
		next;
	}elsif( $expires_flag && /\<td\>(.*)\</ ){
		$profile_data{'expires'} = $1;
		$expires_flag = 0;
		next;
	}elsif( $data_flag && /\<td\>(.*)\</ ){
		$profile_data{'data'} = $1;
		$data_flag = 0;
		next;
	}elsif( /Service Plan/ ){
		$plan_flag = 1;
		next;
	}elsif( /Cash Balance/ ){
		$balance_flag = 1;
		next;
	}elsif( /Airtime Exp Date/ ){
		$expires_flag = 1;
		next;
	}elsif( /\<td\>Data\<\/td\>/ ){
		$data_flag = 1;
	}
}
close $profile_fh;
print "Results of processing $saved_account_profile\nService Plan: $profile_data{'plan'}\nCash Balance: $profile_data{'balance'}\nAirtime Exp Date: $profile_data{'expires'}\nData: $profile_data{'data'}\n";



#WORKS!

=comment
Returned html source in 2.html:
href="/my-account/account-profile?a=1917166">Account Profile</a></div>
href="/my-account/call-details?a=1917166">Call Details
=cut


