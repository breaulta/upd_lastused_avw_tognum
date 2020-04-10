#!/usr/bin/perl
use warnings;
use strict;

#REMEMBER TO PUSH CHANGES TO EDITOR.PM AS WELL

#Use home-built Gnumeric spreadsheet editing module.
use lib '/home/portal/testing/';
#Aaron's lib for testing.
#use lib '/home/newputer/avw-proj';
use Editor;
#For logging into Airvoice Wireless accounts.
use WWW::Mechanize;

#Hash to hold Gnumeric phone plan spreadsheet field names as keys, column letters as values.
my %ss_field_to_letter = (
        email           => 'E',
        plan            => 'F',
        balance         => 'G',
        expire          => 'K',
        call_date       => 'M',
        text_date       => 'N',
        data_date       => 'O',
        rem_data        => 'P'
);

#Open spreadsheet for reading/writing.
my $editor = new Editor('phone_plans.gnumeric');
#Used for testing.
#my $editor = new Editor('sample_spreadsheet.gnumeric');

#Get airvoice password.
my $password = get_password();

#Create hashref, emails as keys, cell row #s as values.
my $email_to_row_hashref = get_emails();

#Login to each account, populate account_data hash, and write the data to a new file.
foreach my $email (keys %$email_to_row_hashref){
	my $data_hashref = get_account_data($email, $password, 1);
	$editor->writecell($ss_field_to_letter{'expire'} . $$email_to_row_hashref{$email}, $$data_hashref{'plan_expire_date'});
	$editor->writecell($ss_field_to_letter{'call_date'} . $$email_to_row_hashref{$email}, $$data_hashref{'last_call_date'});
	$editor->writecell($ss_field_to_letter{'text_date'} . $$email_to_row_hashref{$email}, $$data_hashref{'last_outgoing_text_date'});
	$editor->writecell($ss_field_to_letter{'data_date'} . $$email_to_row_hashref{$email}, $$data_hashref{'last_data_date'});
	$editor->writecell($ss_field_to_letter{'rem_data'} . $$email_to_row_hashref{$email}, $$data_hashref{'remaining_data'});
	$editor->savefile('test.gnumeric');
}

# Read in all accounts (email addresses) from gnu spreadsheet.
sub get_emails {
	my %email_to_row;
	for (my $row = 4; $row == scalar (keys %email_to_row) + 4; $row++ ) {
last if $row == 5;  #remove this line to cycle through all accounts.
		my $email = $editor->readcell($ss_field_to_letter{'email'} . $row);
		$email_to_row{$email} = $row if defined $email;
	}
	return \%email_to_row;
}

sub get_account_data {
	my $username = shift;
	my $account_pass = shift;
	my $login_attempt_num = shift;

	#Login to account.
	my $base_url = 'https://www.airvoicewireless.com';
	my $mech = WWW::Mechanize->new();
	sleep(1); #Sleep 1 second to give Airvoice's site a break.
	$mech->get($base_url . "/login");
	sleep(1);
	$mech->submit_form(
		form_id => 'login-form',
		#form_number => 1,
		fields      => {
			form      => 'login',
			email     => $username,
			password  => $account_pass,
		}
	);
	sleep(1);

	#Determine account number.
	unless ($mech->text() =~ m/Your associated account\(s\) are: (\d+)/){
		die "Cannot aquire account number!\n" if $login_attempt_num > 2;
		$login_attempt_num++;
		print "Couldn't find account number. Attempting pass number: $login_attempt_num\n";
		return get_account_data($username, $account_pass, $login_attempt_num);
	}
	my $account_number = $1;
	#Let the user know how the script is progressing.
	print "Successfully logged in! Account number: $account_number\n";

	#Fetch call details data for account.
	$mech->get($base_url . "/my-account/call-details?a=" . $account_number);
	sleep(1);
	my $call_details_html = $mech->content( decoded_by_headers => 1 );
	unless ($call_details_html =~ m/Call Records/){
		die "Call details page failed to load for account $username\n" if $login_attempt_num > 2;
		$login_attempt_num++;
		print "Couldn't call details page. Attempting pass number: $login_attempt_num\n";
		return get_account_data($username, $account_pass, $login_attempt_num);
	}
	my @call_details_html = split /\n/, $call_details_html;

	#Hash to hold account information.
	my %phone_fields = (
		#Last call date (either incoming or outgoing) from Call Records
		last_call_date => undef,
		#Last outgoing text date from SMS Records
		last_outgoing_text_date => undef,
		#Last data use date from Data Records.
		last_data_date => undef,
		#Service plan type.
		plan_type => undef,
		#Balance left for Pay-as-Go plan.
		account_balance => undef,
		#Date that plan expires.
		plan_expire_date => undef,
		#Data remaining before renewal date.
		remaining_data => undef
	);

	#Find last call date in Call Records (the 1st section) of html.
	while (@call_details_html){
		my $html_line = shift @call_details_html;
		$phone_fields{'last_call_date'} = $1 if $html_line =~ m/date..(\d{2}.\d{2}.\d{4})/ and not defined $phone_fields{'last_call_date'};
		last if $html_line =~ m/SMS Records/; #We're past call records and into text records.
	}

	#Find last outgoing text date in SMS Records section of html.
	my $previous_html_line = ''; #for determining if sms was outgoing
	while (@call_details_html){
		my $html_line = shift @call_details_html;
		$phone_fields{'last_outgoing_text_date'} = $1 if $previous_html_line =~ m/Outgoing/ and $html_line =~ m/date..(\d{2}.\d{2}.\d{4})/ and not defined $phone_fields{'last_outgoing_text_date'};
		$previous_html_line = $html_line;
		last if $html_line =~ m/Data Records/; #We're past call records and into text records.
	}

	#Find last data use date in Data Records section of html.
	while (@call_details_html){
		my $html_line = shift @call_details_html;
		$phone_fields{'last_data_date'} = $1 if $html_line =~ m/date..(\d{2}.\d{2}.\d{4})/ and not defined $phone_fields{'last_data_date'};
	}

	#Fetch account information HTML for account.
	$mech->get($base_url . "/my-account/account-information?a=" . $account_number);
	sleep(1);
	my $account_info_html = $mech->content( decoded_by_headers => 1 );
	unless ($account_info_html =~ m/Airtime Exp Date/){
		die "Account information page failed to load for account $username\n" if $login_attempt_num > 2;
		$login_attempt_num++;
		print "Couldn't account information page. Attempting pass number: $login_attempt_num\n";
		return get_account_data($username, $account_pass, $login_attempt_num);
	}
	$phone_fields{'plan_type'} = $1 if $account_info_html =~ m/"PlanName":"([^"]+)"/;
	$phone_fields{'account_balance'} = $1 if $account_info_html =~ m/"AccountBalance":"(\$\d{1,2}\.\d{2})"/;
	#Formatted as MM/DD/YYYY.
	$phone_fields{'plan_expire_date'} = "$2/$3/$1" if $account_info_html =~ m/"AirtimeExpDate":"(\d{4})-(\d{2})-(\d{2})[^"]+"/;
	#Grab kb data, divide to turn to gb, round to 2 decimals.
	$phone_fields{'remaining_data'} = sprintf("%.2f GB", $1/1048576) if $account_info_html =~ m/"Data":"(\d+)"/;
	#Ensure that no fields have been left undefined before returning hashref.
	foreach my $field (keys %phone_fields){
		unless (defined $phone_fields{$field}){
			die "Field $field is undefined for account $username\n" if $login_attempt_num > 2;
			$login_attempt_num++;
			return get_account_data($username, $account_pass, $login_attempt_num);
		}
	}
	return \%phone_fields;	
}


sub get_password {
	system ("stty", "-echo");
	print "Enter password: \n";
	my $pass = <>;
	system ("stty", "sane");
	chomp $pass;
	return $pass;
}

