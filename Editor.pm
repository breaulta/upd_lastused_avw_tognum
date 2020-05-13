package Editor;

use strict;
use warnings;

#Needed for spreadsheet epoch calculation.
use Date::Calc qw(:all);

#Hash to map cell letters of Gnumeric spreadsheet to column numbers.
#Map range is from column 'A' to 'ZZZ', or 0 to 18277 in column numbers.
my %column_letter_to_number_gnumeric_map;
for (my $letter = 'A', my $number = 0; $letter ne 'AAAA'; $letter++, $number++){
	$column_letter_to_number_gnumeric_map{$letter} = $number;
}

#Array to keep working draft of Gnumeric file being edited.
my @current_working_file;

#Create Gnumeric spreadsheet object for reading and writing.
sub new {
	my $class = shift;
	my $self = {@_};
	bless $self, $class;

	#Check that file is good gnumeric file.
	my $filename = $self->{filename};
	my $filename_noextension;
	if ($filename =~ /(.+)\.gnumeric$/){
		$filename_noextension = $1;
	}
	else{
		die "Specified file $filename doesn't appear to be a gnumeric spreadsheet"
	}
	die "Specified file $filename doesn't exist!"
		unless -e $filename;
	#Gnumeric files are compressed using gzip, unzip copy of file for editing.
	my $gz_filename = $filename_noextension . ".gz";
	system("cp", $filename, $gz_filename) == 0 or die "Could not copy $filename: $?";
	system("gunzip", $gz_filename) == 0 or die "Could not unzip $gz_filename: $?";
	#Read file into global array for use in this instance of the Editor object.
	open (my $unzipped_fh, "<", $filename_noextension);
	chomp( @current_working_file = <$unzipped_fh> );
	close $unzipped_fh;
	unlink $filename_noextension;

	return $self;
}

#Save file to output filename specified in first parameter.
sub savefile {
	my $self = shift;
	my $output_filename = shift;

	#Overwrite original file if no alternative output filename was specified.
	$output_filename = $self->{filename}
		unless defined $output_filename;
	die "Output file $output_filename doesn't appear to be a gnumeric spreadsheet"
		unless $output_filename =~ /.+\.gnumeric$/;
	#Write edited Gnumeric file stored in memory as an array to hard disk.
	open (my $output_fh, ">", $output_filename) or die "Can't open file $output_filename: $!";
	foreach(@current_working_file){
		print $output_fh "$_\n";
	}
	close $output_fh;
	#Gzip file.
	system("gzip", $output_filename) == 0 or die "Could not gzip $output_filename: $?";
	system("mv", "$output_filename.gz", $output_filename) == 0 or die "Could not move $output_filename: $?";
}

sub readcell {
	my $self = shift;
	my $cell = shift;

	#Split letter from number
	die "readcell call not executed properly: Failed to split cell index letter from number."
		unless $cell =~ /(\w)(\d+)/;
	my $column = uc $1;	#Set everything to uppercase.
	my $cell_row = $2;
	#Dereference letter to number using %column_letter_to_number_gnumeric_map
	my $cell_column = $column_letter_to_number_gnumeric_map{$column};
	#Rows start at 0 in the gnu spreadsheet; decrement to align.
	$cell_row--;

	#Find the most uniquely formatted line that matches the corresponding row+colum.
	foreach my $line (@current_working_file){
		#The date type of line also has a ValueType and ValueFormat,
		# but no other format has m/d/yyyy format: take it first.
		if( $line =~ /Row..$cell_row. Col..$cell_column.+\"m\/d\/yyyy\"\>(.+)\</ ){
			return _ss_num_to_date( $1 );
		#Take the conditinally formatted (ValueFormat) cell next.
		}elsif( $line =~ /Row..$cell_row. Col..$cell_column.+ValueFormat..\S+..(.+)\</ ){
			return $1;
		#We've run out of special types; just find the cell and return its contents.
		}elsif( $line =~ /Row..$cell_row. Col..$cell_column.+ValueType..\d+..(.+)\</ ){
			return $1;
		}
	}
}

sub writecell {
	my $self = shift;
	my $cell = shift;
	my $data_to_write = shift;

	die "writecell call received undefined input!"
		unless defined $data_to_write;
	if ($data_to_write eq "") {
		print "No data to write; deleting cell $cell\n";
	}
	#Split letter from number
	die "Failed to split cell index letter from number."
		unless $cell =~ /(\w)(\d+)/;
	my $column = uc $1;	#Set everything to uppercase.
	my $cell_row = $2;
	#Dereference letter to gnu number using %column_letter_to_number_gnumeric_map
	my $cell_column = $column_letter_to_number_gnumeric_map{$column};
	#Rows start at 0 in the gnu spreadsheet; decrement to align.
	$cell_row--;
	
	#Similarly to readcell, look for the most unique line that matches the cell row and column.
	# This time, however, we need to make sure the data is formatted correctly and wrapped in a 
	# correctly formatted xml/gnm line.
	for( my $i = 0; $i < scalar @current_working_file; $i++){
		#Copy line for editing.
		my $line = $current_working_file[$i];
		#Check if the given cell matches a date formatted gnumeric xml line.
		if( $line =~ /Row..$cell_row. Col..$cell_column.+\"m\/d\/yyyy\"\>(.*)\</ ){
			#We're writing to the spreadsheet so we need the date in epoch format.
			my $epoch_date = _ss_date_to_num($data_to_write);
			#Match everything before and after where the cell data lives and 
			# wrap that around the epoch date number to form our completed line.
			$line =~ s/(\<gnm\:Cell Row\=\"$cell_row\" Col\=\"$cell_column\" ValueType\=\"\d+\"\ ValueFormat\=\"m\/d\/yyyy\"\>)(.*)(\<\/gnm\:Cell\>)/$1$epoch_date$3/;
			#Write modified line to our current working file, replacing the old line.
			$current_working_file[$i] = $line;
			#Our job is done; no need to search through the rest of the file.
			return;
		#Check for match and replace line with wrapped data_to_write to commplete our ValueFormat line.
		} elsif( $line =~ s/(\<gnm\:Cell Row\=\"$cell_row\" Col\=\"$cell_column\" ValueType\=\"\d+\"\ ValueFormat\=\"\S+\"\>)(.*)(\<\/gnm\:Cell\>)/$1$data_to_write$3/){
			$current_working_file[$i] = $line;
			return;
		#Check if the current line matches this format as well as the given column/row combination and if it does,
		# wrap the to-be-inputted data with the matched xml both before and after the location of the data.
		}elsif( $line =~ s/(\<gnm\:Cell Row\=\"$cell_row\" Col\=\"$cell_column\" ValueType\=\"\d+\"\>)(.+)(\<\/gnm\:Cell\>)/$1$data_to_write$3/){
			$current_working_file[$i] = $line;
			return;
		#It looks like we've reached the end of the Cells block. This indicates that we're writing to an empty cell
		# and that we must create a line inside the Cells block to fill the cell.
		}elsif( $line =~ /\<\/gnm\:Cells\>/ ){
			#Create the line we need to insert into the spreadsheet in order to fill the cell.
			$line = "<gnm:Cell Row=\"$cell_row\" Col=\"$cell_column\" ValueType=\"60\">$data_to_write</gnm:Cell>";
			#Insert the line into the file one line above the Cells block terminator (inside the Cells block).
			#We have to use splice here because otherwise a new array location won't be created and subsequently,
			# the line above the Cells block terminator will be clobbered. We have to make the array larger by 1 at this location.
			my $prev_line = $i - 1;
			splice @current_working_file, $prev_line, 0, "<gnm:Cell Row=\"$cell_row\" Col=\"$cell_column\" ValueType=\"60\">$data_to_write</gnm:Cell>";
			return;
		}
	}
}


#Spreadsheets measure dates by an integer count, where the epoch is December 30, 1899. The history behind this decision is found here: https://tinyurl.com/utube75
my $ss_epoch_year = 1899;
my $ss_epoch_month = 12;
my $ss_epoch_day = 30;

#Convert Gnumeric days-from-epoch date, to standard mm/dd/yyyy date.
#Prints "3/12/2020" for sample Gnumeric cell date/day integer "43902".
#print ss_num_to_date("43902"), "\n";
sub _ss_num_to_date {
    my $num = shift;
    #Number must be an integer.
    die "Invalid spreadsheet date number" unless $num =~ m/^\d+$/;
    my ($year,$month,$day) = Add_Delta_Days($ss_epoch_year,$ss_epoch_month,$ss_epoch_day,$num);
    return "$month/$day/$year";

}

#Converts back to Gnumeric days-from-epoch date from mm/dd/yyyy input date.
sub _ss_date_to_num {
    my $date = shift;
    #Date must be in m/d/yyyy format.
    die "Invalid m/d/yyyy format" unless $date =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
    my ($month, $day, $year) = ($1, $2, $3);
    return Delta_Days($ss_epoch_year,$ss_epoch_month,$ss_epoch_day,$year,$month,$day);
}
1;
