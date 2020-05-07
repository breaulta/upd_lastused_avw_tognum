#!/usr/bin/perl
use warnings;
use strict;

#Use home-built Gnumeric spreadsheet editing module.
use lib '.';
use Editor;
#For logging into Airvoice Wireless accounts.
use WWW::Mechanize;
#For use in calculating most recent date.
use Date::Calc qw(:all);

#Hash to hold Gnumeric phone plan spreadsheet field names as keys, column letters as values.
my %ss_field_to_letter = (
        email           => 'E',
        balance         => 'G',
        expire          => 'J',
	last_use_date	=> 'L',
        call_date       => 'M',
        text_date       => 'N',
        data_date       => 'O',
        rem_data        => 'P'
);

#Open spreadsheet for reading/writing.
my $editor = new Editor('phone_plans.gnumeric');

#Get airvoice password.
my $password = get_password();

#Create hashref, emails as keys, cell row #s as values.
my $email_to_row_hashref = get_emails();

#Login to each account, populate account_data hash, and write the data to a new file.
foreach my $email (keys %$email_to_row_hashref){
	my $data_hashref = get_account_data($email, $password, 1);
	#Move onto the next email if we could not get the account details.
	next if $data_hashref == 1;
	#Otherwise, prepare to write the account information to our output file.
	$editor->writecell($ss_field_to_letter{'expire'} . $$email_to_row_hashref{$email}, $$data_hashref{'plan_expire_date'});
	$editor->writecell($ss_field_to_letter{'call_date'} . $$email_to_row_hashref{$email}, $$data_hashref{'last_call_date'});
	$editor->writecell($ss_field_to_letter{'text_date'} . $$email_to_row_hashref{$email}, $$data_hashref{'last_outgoing_text_date'});
	$editor->writecell($ss_field_to_letter{'data_date'} . $$email_to_row_hashref{$email}, $$data_hashref{'last_data_date'});
	$editor->writecell($ss_field_to_letter{'rem_data'} . $$email_to_row_hashref{$email}, $$data_hashref{'remaining_data'});
	#If it's a Pay As Go plan, write the balance to the spreadsheet as well.
	if ( $$data_hashref{'plan_type'} =~ m/^Pay As You Go/ ){
		$editor->writecell($ss_field_to_letter{'balance'} . $$email_to_row_hashref{$email}, $$data_hashref{'account_balance'});
	}
	#Record the most recent use date of the phone.
	my $most_recent_use_date = most_recent_date( $$data_hashref{'last_call_date'}, $$data_hashref{'last_outgoing_text_date'}, $$data_hashref{'last_data_date'} );
	$editor->writecell( $ss_field_to_letter{'last_use_date'} . $$email_to_row_hashref{$email}, $most_recent_use_date ) if defined $most_recent_use_date;
}
$editor->savefile('test.gnumeric');

# Read in all accounts (email addresses) from gnu spreadsheet.
sub get_emails {
	my %email_to_row;
	for (my $row = 4; $row == scalar (keys %email_to_row) + 4; $row++ ) {
		my $email = $editor->readcell($ss_field_to_letter{'email'} . $row);
		$email_to_row{$email} = $row if defined $email;
	}
	return \%email_to_row;
}

sub get_account_data {
	my $username = shift;
	my $account_pass = shift;
	my $login_attempt_num = shift;

	#If this is our fourth login attempt, return 1.
	if ($login_attempt_num == 4){
		return 1;
	}

	#Login to account.
	my $base_url = 'https://www.airvoicewireless.com';
	sleep(2); 
	my $mech = WWW::Mechanize->new();
	$mech->get($base_url . "/login");
	sleep(2);
	$mech->submit_form(
		form_id => 'login-form',
		#form_number => 1,
		fields      => {
			form      => 'login',
			email     => $username,
			password  => $account_pass,
		}
	);
	sleep(2);

	#Determine account number.
	unless ($mech->text() =~ m/Your associated account\(s\) are: (\d+)/){
		if ($login_attempt_num > 3){
			print STDERR "Cannot aquire account number for account $username!\n";
			return 1;
		}
		print "Getting account number for account $username, attempt $login_attempt_num\n";
		sleep 60;
		$login_attempt_num++;
		return get_account_data($username, $account_pass, $login_attempt_num);
	}
	my $account_number = $1;

	#Fetch call details data for account.
	$mech->get($base_url . "/my-account/call-details?a=" . $account_number);
	sleep(2);
	my $call_details_html = $mech->content( decoded_by_headers => 1 );
	unless ($call_details_html =~ m/Call Records/){
		if ($login_attempt_num > 3){
			print STDERR "Call details page failed to load for account $username\n";
			return 1;
		}
		$login_attempt_num++;
		print "Loading Call Details again for $username, attempt $login_attempt_num\n";
		sleep 60;
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
		#We're past call records, continue onto text records.
		if ($html_line =~ m/SMS Records/){
			#If there was no phone record, note as not found.
			$phone_fields{'last_call_date'} = "Not found" if not defined $phone_fields{'last_call_date'};
			last;
		}
	}

	#Find last outgoing text date in SMS Records section of html.
	my $previous_html_line = ''; #for determining if sms was outgoing
	while (@call_details_html){
		my $html_line = shift @call_details_html;
		$phone_fields{'last_outgoing_text_date'} = $1 if $previous_html_line =~ m/Outgoing/ and $html_line =~ m/date..(\d{2}.\d{2}.\d{4})/ and not defined $phone_fields{'last_outgoing_text_date'};
		$previous_html_line = $html_line;
		#We're past text records, continue onto data records.
		if ($html_line =~ m/Data Records/){
			#If there was no text record, note as not found.
			$phone_fields{'last_outgoing_text_date'} = "Not found" if not defined $phone_fields{'last_outgoing_text_date'};
			last;
		}
	}

	#Find last data use date in Data Records section of html.
	while (@call_details_html){
		my $html_line = shift @call_details_html;
		$phone_fields{'last_data_date'} = $1 if $html_line =~ m/date..(\d{2}.\d{2}.\d{4})/ and not defined $phone_fields{'last_data_date'};
	}
	#If there was no data record, note as not found.
	$phone_fields{'last_data_date'} = "Not found" if not defined $phone_fields{'last_data_date'};

	#Fetch account information HTML for account.
	$mech->get($base_url . "/my-account/account-information?a=" . $account_number);
	sleep(2);
	my $account_info_html = $mech->content( decoded_by_headers => 1 );
	unless ($account_info_html =~ m/Airtime Exp Date/){
		if ($login_attempt_num > 3){
			print STDERR "Account information page failed to load for account $username\n";
			return 1;
		}
		$login_attempt_num++;
		print "Loading Account Information again for $username, attempt $login_attempt_num\n";
		sleep 60;
		return get_account_data($username, $account_pass, $login_attempt_num);
	}
	$phone_fields{'plan_type'} = $1 if $account_info_html =~ m/"PlanName":"([^"]+)"/;
	$phone_fields{'account_balance'} = $1 if $account_info_html =~ m/"AccountBalance":"(\$\d{1,2}\.\d{2})"/;
	#Formatted as MM/DD/YYYY.
	$phone_fields{'plan_expire_date'} = "$2/$3/$1" if $account_info_html =~ m/"AirtimeExpDate":"(\d{4})-(\d{2})-(\d{2})[^"]+"/;
	#Store remaining cell data. Take KiB and divide by conversion factor to convert to GiB and round to 2 decimals.
        if ($account_info_html =~ m/"Data":"(\d+)"/){
                $phone_fields{'remaining_data'} = sprintf("%.2f GB", $1/1048576);
        }
        #Account for the fact that remaining data reads "Unavailable" for "Pay As You Go" plans.
        elsif ($account_info_html =~ m/"Data":"([A-Za-z]+)"/) {
                $phone_fields{'remaining_data'} = $1;
        }
	#Ensure that no fields have been left undefined before returning hashref.
	#Note: "last_---_date" fields taken from the Call Records page will always be defined here,
	#as they are set as "Not found" if they are not found in the Call Records html source.
	foreach my $field (keys %phone_fields){
		unless (defined $phone_fields{$field}){
			die "Field $field is undefined for account $username\n" if $login_attempt_num > 3;
			$login_attempt_num++;
			print "Field $field is not defined for account $username so trying again, attempt $login_attempt_num\n";
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

#Accepts a list of m/d/yyyy dates, returns the most recent date, or undef if no valid dates.
sub most_recent_date {
	#Remove invalid dates.
	my @valid_dates;
	while (my $date = shift){
		push @valid_dates, $date if $date =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
	}
	#Return undefined if no valid dates.
	return undef unless @valid_dates;
	#Grab the first valid date.
	my $most_recent_date = shift @valid_dates;
	#Sort through dates until the most recent one is found.
	while( my $try_date = shift @valid_dates ){
		my ($recent_month, $recent_day, $recent_year) = ($1, $2, $3) if $most_recent_date =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
		my ($try_month, $try_day, $try_year) = ($1, $2, $3) if $try_date =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
		#If try date is more recent, it becomes the new "most recent" candidate.
		$most_recent_date = $try_date if 0 < Delta_Days($recent_year,$recent_month,$recent_day,$try_year,$try_month,$try_day);
	}
	return $most_recent_date;
}

