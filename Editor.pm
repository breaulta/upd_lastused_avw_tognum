package Editor;

use strict;
use warnings;

#Needed for epoch calculation.
use Date::Calc qw(:all);

my $ss_epoch_year = 1899;
my $ss_epoch_month = 12;
my $ss_epoch_day = 30;

# Hash to map cell cell_to_gnu_map to the corresponding numbers used by gnumeric spreadsheet.
my %cell_to_gnu_map = (
	A => 0, B => 1, C => 2, D => 3, E => 4, F => 5, G => 6, H => 7, I => 8, J => 9,
	K => 10, L => 11, M => 12, N => 13, O => 14, P => 15, Q => 16,
);
#my $temp_file = "current_working_temp_file";
my @temp_file;

sub new {
	my ($class, $filename) = @_;
	die "Specified file $filename doesn't appear to be a gnumeric spreadsheet"
		unless $filename =~ /.+\.gnumeric$/;
	die "Specified file $filename doesn't exist!"
		unless -e $filename;
	#https://perldoc.perl.org/functions/bless.html
	#Instantiates the Class into the Object?
	my $self = bless { 
		filename => $filename, 
	}, $class;
	my $gnumeric_ss = $filename;
	#
	$gnumeric_ss =~ /(.+)\.gnumeric$/;
	my $ss = $1;
	my $gz_ss = "$1.gz";
	#Convert file to type that is useable by perl.
	#Read file into global array for use in this instance of object.
	system("cp", $gnumeric_ss, $gz_ss) == 0 or die "System call failed: $?";
	system("gunzip", $gz_ss) == 0 or die "System call failed: $?";
	#system("mv", $ss, $temp_file) == 0 or die "System call failed: $?";
my $temp_fh;
	open ($temp_fh, "<", $ss) or die "Can't open $temp_fh: $!";
	chomp(@temp_file = <$temp_fh>);
	close $temp_fh;

	return $self;
}

sub savefile {
	my $self = shift;
	my $filename = shift;

	# Save file to original if no file is passed.
	if( $filename eq ""){
		$filename = $self->filename;
	}
	die "Specified file $filename doesn't appear to be a gnumeric spreadsheet"
		unless $filename =~ /.+\.gnumeric$/;

	#system("gzip", $temp_file) == 0 or die "System call failed: $?";
	#system("mv", "$temp_file.gz", $filename) == 0 or die "System call failed: $?";
	#Print each line of @temp_file into a file to save.
my $fh;
	open ($fh, ">", $filename) or die "Can't open $fh: $!";
	#open( my $fh, "<", $temp_file) or die "Can't open $temp_file: $!";
	foreach(@temp_file){
		print $fh "$_\n";
	}
	close $fh;

}

sub readcell {
	my $self = shift;
	my $cell = shift;
	my $data;

	#B3 translates to Col="1 "Row="2"
	#<gnm:Cell Row="2" Col="1" ValueType="60">Number</gnm:Cell>
	
	#Split letter from number
# Wrap this in an if statement to make sure it completes properly.
	$cell =~ /(\w)(\d+)/;
	my $column = uc $1;	#Set everything to uppercase.
	my $row = $2;
#	print "Reading user input- Col:$column, Row:$row\n";

	#Dereference letter to number using %cell_to_gnu_map, rows start at 0 instead of 1.
	my $gnu_column = $cell_to_gnu_map{$column};
	# gnumeric uses 0 for row 1.
	$row--;

	#Find line that corresponds to cell
	#Open file associated with this object
	#open( my $fh, "<", $temp_file) or die "Can't open $temp_file: $!";
	#Read in contents in form that can be regex'd
	#while( my $line = <$fh> ){
	foreach my $line (@temp_file){
		#	Loop through lines until <gnm:Cell Row="2" Col="1" ValueType="60">Number</gnm:Cell> is found.
		if ($line =~ /\<gnm\:Cell Row\=\"$row\" Col\=\"$gnu_column\" ValueType\=\"\d+\"\ ValueFormat\=\"m\/d\/yyyy\"\>(.+)\<\/gnm\:Cell\>/ ){
			#print "#$. Epoch Formatted data: $1\n";
			return _ss_num_to_date( $1 );
			#print "#$. Date Formatted data: $date\n";
		} elsif ( $line =~ /\<gnm\:Cell Row\=\"$row\" Col\=\"$gnu_column\" ValueType\=\"\d+\"\ ValueFormat\=\"\S+\"\>(.+)\<\/gnm\:Cell\>/ ){
			# Data is held in $1
			#print "#$. Other Conditional data: $1\n";
			return $1;
		} elsif( $line =~ /\<gnm\:Cell Row\=\"$row\" Col\=\"$gnu_column\" ValueType\=\"\d+\"\>(.+)\<\/gnm\:Cell\>/ ){
			# Data is held in $1
			#print "#$. Non-Conditional data: $1\n";
			return $1;
		}
		#Exit loop so that hidden historical gnumeric cell data doesn't overwrite visible cell data stored in $data.
		#last if $line =~ m/<\/gnm:Cells>/;
	}
	#close($fh);
	#return $data;
}

sub writecell {
	my $self = shift;
	my $cell = shift;
	my $data = shift;

	# Len suggests to check for undef data => kill program.
	if ($data eq "") {
		print "No data to write; deleting cell $cell\n";
	}
# write a sub for converting cell names to gnumeric cell format.
	#Split letter from number
	$cell =~ /(\w)(\d+)/;
	my $column = uc $1;	#Set everything to uppercase.
	my $row = $2;
	#print "Reading user input- Col:$column, Row:$row\n";

	#Dereference letter to number using %cell_to_gnu_map, rows start at 0 instead of 1.
	my $gnu_column = $cell_to_gnu_map{$column};
	$row--;
	#print "Type used by gnumeric- Col:$column, Row:$row\n";

	#Find line that corresponds to cell
	#	open file associated with this object
	#open( my $fh, "<", $temp_file) or die "Can't open $temp_file: $!";
	#	from: https://stackoverflow.com/questions/2278527/how-do-i-replace-lines-in-the-middle-of-a-file-with-perl
	#	Since perl doesn't provide random access to lines, we must create a new file.
#	open( my $fhout, ">", "$temp_file.out") or die "Can't open $temp_file.out: $!";
	#	
#	while( <$fh> ){
	#Keep track of the current index of the array.
	my $i = 0;
	foreach (@temp_file){
		#	
		if ( /\<gnm\:Cell Row\=\"$row\" Col\=\"$gnu_column\" ValueType\=\"\d+\"\ ValueFormat\=\"m\/d\/yyyy\"\>(.*)\<\/gnm\:Cell\>/ ){
			die "Data format \"mm/dd/yyy\" expected for this cell."
				unless $data =~ /^\d\d\/\d\d\/\d\d\d\d$/;
			my $epoch = _ss_date_to_num($data);
			s/(\<gnm\:Cell Row\=\"$row\" Col\=\"$gnu_column\" ValueType\=\"\d+\"\ ValueFormat\=\"m\/d\/yyyy\"\>)(.*)(\<\/gnm\:Cell\>)/$1$epoch$3/;
		} elsif( s/(\<gnm\:Cell Row\=\"$row\" Col\=\"$gnu_column\" ValueType\=\"\d+\"\ ValueFormat\=\"\S+\"\>)(.*)(\<\/gnm\:Cell\>)/$1$data$3/){print "Conditional\n";}
		elsif( s/(\<gnm\:Cell Row\=\"$row\" Col\=\"$gnu_column\" ValueType\=\"\d+\"\>)(.+)(\<\/gnm\:Cell\>)/$1$data$3/){print "nonconditional\n";}
		elsif( /\<\/gnm\:Cells\>/ ){
			# Did not find a line to change (cell is empty): create line at the end of gnm:Cell block.
			#print $fhout "<gnm:Cell Row=\"$row\" Col=\"$gnu_column\" ValueType=\"60\">$data</gnm:Cell>\n";
			#print $_ "<gnm:Cell Row=\"$row\" Col=\"$gnu_column\" ValueType=\"60\">$data</gnm:Cell>\n";
			my $num = $i - 1;
			#my $line = "<gnm:Cell Row=\"$row\" Col=\"$gnu_column\" ValueType=\"60    \">$data</gnm:    Cell>":
			splice @temp_file, $num, 0, "<gnm:Cell Row=\"$row\" Col=\"$gnu_column\" ValueType=\"60\">$data</gnm:    Cell>";
			#splice @temp_file, $num, 0, $line;
		}
		# Print line to outfile after changes have been made.
#		print $fhout $_;
		$i++;
	}
	#close $fh;
	#close $fhout;
	#system("rm", $temp_file) == 0 or die "System call failed: $?";
	#system("mv", "$temp_file.out", $temp_file) == 0 or die "System call failed: $?";
	
}

sub _ss_num_to_date {
    my $num = shift;
    #Number must be an integer.
    die "Invalid spreadsheet date number" unless $num =~ m/^\d+$/;
    my ($year,$month,$day) = Add_Delta_Days($ss_epoch_year,$ss_epoch_month,$ss_epoch_day,$num);
    return "$month/$day/$year";

}

sub _ss_date_to_num {
    my $date = shift;
    #Date must be in m/d/yyyy format.
    die "Invalid m/d/yyyy format" unless $date =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
    my ($month, $day, $year) = ($1, $2, $3);
    return Delta_Days($ss_epoch_year,$ss_epoch_month,$ss_epoch_day,$year,$month,$day);
}

#Leaving this unneeded sub for reference for now.
##sub openfile {
#	my $self = shift;
#	my $gnumeric_ss = $self->{file};
#
#	#Use regex so code is applicable to any filename.
#	$gnumeric_ss =~ /(.+)\.gnumeric$/;
#	my $ss = $1;
#	my $gz_ss = "$1.gz";
#
#	#Convert file to type that is useable by perl.
#	rename $gnumeric_ss, $gz_ss;
#	system("gunzip", $gz_ss) == 0 or die "System call failed: $?";
#	system("cp", $ss, "copyof_sample_spreadsheet");
#
#	#cleanup
#	system("gzip", $ss) == 0 or die "System call failed: $?";
#	system("mv", $gz_ss, $gnumeric_ss) == 0 or die "System call failed: $?";
#	#'copyof_spreadsheet' file not cleaned up for now for testing.
#}

1;
