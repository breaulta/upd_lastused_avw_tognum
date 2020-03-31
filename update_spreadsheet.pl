#!/usr/bin/perl
use warnings;
use strict;

# Required for linux.
use lib '/home/newputer/avw-proj';
use Editor;
use WWW::Mechanize;

my $base_url = 'https://www.airvoicewireless.com';
my $editor = new Editor('sample_spreadsheet.gnumeric');
my $mech = WWW::Mechanize->new();

# Read in all accounts (emails) from gnu spreadsheet.
# Column 'E' has the emails and starts at 'E4'.
my $i = 4;
my $cell;
my $email;
my %emails;
# while($email){
while(1){
	$cell = 'E' . $i;
	$email = $editor->readcell($cell);
	# We have past the last account, exit loop.
	if( !$email ){ last;}
	#push @emails, $email;
	$emails{$i} = $email;
	print $i . ' ' . "$cell\n";
	$i++;
}

my %data = (
	call => '',
	text => '',
	ldata => '',
	plan => '',
	balance => '',
	expires => '',
	data => '',
);
my $saved_call_details = "call_details.html";
my $saved_account_profile = "account_profile.html";
foreach my $row (keys %emails){
	# Get password
	system ("stty", "-echo");
	print "Enter password: \n";
	my $password = <>;
	system ("stty", "sane");
	chomp $password;

	#Login to account.
	$mech->get($base_url . "/login");
	$mech->submit_form(
		form_id => 'login-form',
		#form_number => 1,
		fields      => {
			form      => 'login',
			email     => $emails{$row},
			password  => $password,
		}
	);
	#Determine account number.
	die "Cannot find account number!" unless $mech->text() =~ m/Your associated account\(s\) are: (\d+)/;
	my $account_number = $1;
	print "Found account number => Successfully logged into system!\n";

	#Fetch call details text.
	$mech->get($base_url . "/my-account/call-details?a=" . $account_number);
	my $call_details = $mech->content( decoded_by_headers => 1 );
	open (my $call_file, ">", $saved_call_details) or die "Can't open $saved_call_details: $!";
	print $call_file $call_details;
	close $call_file;

	sleep(1);	#Sleep 1 second as to not get flagged for ddos.
	#Fetch account profile text.
	$mech->get($base_url . "/my-account/account-information?a=" . $account_number);
	my $account_profile = $mech->content( decoded_by_headers => 1 );
	open (my $profile_file, ">", $saved_account_profile) or die "Can't open $saved_account_profile $!";
	print $profile_file $account_profile;
	close $profile_file;

	extract_avw_data(\%data);
	print "data: $data{'data'}\n";
	print "ldata: $data{'ldata'}\n";

	# call		M
	# last text	N
	#last data	O
	#plan		F
	#balance	G
	#expires	undef
	#data left	P
	$cell = 'M' . $row;
	$editor->writecell($cell, $data{'call'});
	$cell = 'N' . $row;
	$editor->writecell($cell, $data{'text'});
	$cell = 'O' . $row;
	$editor->writecell($cell, $data{'ldata'});
	$cell = 'F' . $row;
	$editor->writecell($cell, $data{'plan'});
	$cell = 'G' . $row;
	$editor->writecell($cell, $data{'balance'});
	$cell = 'P' . $row;
	$editor->writecell($cell, $data{'data'});
	$editor->savefile('test.gnumeric');
}

sub extract_avw_data {
	my ($data) = @_;	# Hash reference.

	my $call_flag = 0;	# Off.
	my $text_flag = 0;
	my $data_flag = 0;
	my $outgoing_flag = 0;
	open( my $call_fh, "<", $saved_call_details) or die "Can't open $saved_call_details: $!";
	while( <$call_fh> ){
		# Using an if-block filter to find datas.
		if( $outgoing_flag && /class\=\"cell date\"\>(.*)\</ ){
			# Grab the data in the line after 'Outgoing' was found.
			$$data{'text'} = $1;
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
			$$data{'call'} = $1;
			$call_flag = 0;	
			next;
		}elsif( $data_flag && /class\=\"cell date\"\>(.*)\</ ){
			$$data{'ldata'} = $1;
			$data_flag = 0;	
		}
	}
	close $call_fh;
	print "Results of processing $saved_call_details:\nlast call: $$data{'call'}\nlast text: $$data{'text'}\nlast data: $$data{'ldata'}\n";

	my $plan_flag = 0;	# Off.
	my $balance_flag = 0;
	my $expires_flag = 0;
	$data_flag = 0;
	open( my $profile_fh, "<", $saved_account_profile) or die "Can't open $saved_account_profile $!";
	while( <$profile_fh> ){
		# Using an if-block filter to find datas.
		if( $plan_flag && /class\=\"blue\"\>(.*)\<\/span/ ){
			$$data{'plan'} = $1;
			$plan_flag = 0;
			next;
		}elsif( $balance_flag && /\<td\>\$(.*)\</ ){
			$$data{'balance'} = $1;
			$balance_flag = 0;
			next;
		}elsif( $expires_flag && /\<td\>(.*)\</ ){
			$$data{'expires'} = $1;
			$expires_flag = 0;
			next;
		}elsif( $data_flag && /\<td\>(.*)\</ ){
			$$data{'data'} = $1;
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
	print "Results of processing $saved_account_profile\nService Plan: $$data{'plan'}\nCash Balance: $$data{'balance'}\nAirtime Exp Date: $$data{'expires'}\nData: $$data{'data'}\n";

}

#WORKS!

=comment
Returned html source in 2.html:
href="/my-account/account-profile?a=1917166">Account Profile</a></div>
href="/my-account/call-details?a=1917166">Call Details
=cut


