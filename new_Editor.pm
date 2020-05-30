package Editor;

use strict;
use warnings;

#Class reads and writes edits to Gnumeric spreadsheets.

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
#REMOVE THIS.
open (my $f, ">", "xml.txt");
foreach(@current_working_file){
	print $f "$_\n";
}
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

#Reads and returns the contents of the spreadsheet cell (specified as 'B5').
sub readcell {
	my $self = shift;
	my $cell = shift;

	#Get XML accessible column and row coordinates from Gnumeric cell name.
	my ($cell_column, $cell_row) = _convert_cell_to_column_and_row_coordinates($cell);
	#Return Gnumeric cell contents, applying any needed format conversions.
	foreach my $line (@current_working_file){
		#Match for specially formatted date cells first.
		#Dates are stored as integers, so convert to mm/dd/yyyy format.
		if( $line =~ /Row..$cell_row. Col..$cell_column.+"m\/d\/yyyy">(\d+)</ ){
			return _ss_num_to_date( $1 );
		#Match standard cell contents.
		} elsif( $line =~ /Row..$cell_row. Col..$cell_column.+>(.*)</){
			return $1;
		#Check for any matching errors.
		} elsif( $line =~ /Row..$cell_row. Col..$cell_column/ )  {
			#It's a Gnumeric cell Jim, but not as we know it.
			die "Could not extract Gnumeric cell contents for cell $cell\nline: $line\n";
		}
		#Exit loop once end of cells are reached.
		#This is done to omit historical invisible cell saved at the end of the file.
		last if $line =~ m/<\/gnm:Cells>/;
	}
	#After having searched every line of the file, we can conclude the cell is blank.
	return "";
}

#Writes data to the specified cell stored in memory.
#Note: savefile() method must be called in order to write any changes made here to disk.
sub writecell {
	my $self = shift;
	my $cell = shift;
	my $data_to_write = shift;

	die "writecell call received undefined input!"
		unless defined $data_to_write;
	#Get XML accessible column and row coordinates from Gnumeric cell name.
	my ($cell_column, $cell_row) = _convert_cell_to_column_and_row_coordinates($cell);

	#Array to take lines from as we're going through the file.
	my @current_working_file_copy = @current_working_file;
	#Array to write edits to, before they're copied to the @current_working_file array.
	my @new_current_working_file;
	#Boolean to note if cell has been written or not.
	my $cell_has_not_been_written = 1;
	#Go through current version of file, and edit the appropriate cell.
	while (@current_working_file_copy){
                my $line = shift @current_working_file_copy; #Line from our working file.
		my $new_line;	#Line to add to our new working file.
		#Find the line containing our target cell and get the newly edited line given the specified parameters.
		if ( $line =~ /Row..$cell_row. Col..$cell_column/ and $cell_has_not_been_written ){
			$new_line = _get_new_gnumeric_line($cell_column, $cell_row, $data_to_write);
			$cell_has_not_been_written = 0; #It has now, or more accurately, will be shortly...
		}
		#If we reach the end of the spreadsheet, and we still need to write a cell, do so.
		elsif ( $line =~ m/<\/gnm:Cells>/ and $cell_has_not_been_written ){
			#This will create a brand new line for holding the specified data in a new cell.
			$new_line = _get_new_gnumeric_line($cell_column, $cell_row, $data_to_write);
			push @new_current_working_file, $new_line;
			$cell_has_not_been_written = 0; #Now it has.
			#Then set the new line as the old line (the Gnumeric cell closing tag), to close the active cells.
			$new_line = $line;
		}
		#Otherwise, our new line is the same as the old line.
		else{
			$new_line = $line;
		}
		#Add our new line to our new working file array.
		push @new_current_working_file, $new_line;
	}
	#With our targeted cell modified in the new array, commit the edit to our working file array.
	@current_working_file = @new_current_working_file;
}

#Given a target cell, data to put in that cell, and the Gnumeric line which represents that cell,
#generate and return a new line to put in the Gnumeric file to represent the specified cell and it's data.
#-------Return blank for empty cell------
sub _get_new_gnumeric_line {
	my $column = shift;
	my $row = shift;
	my $cell_data = shift;

	#For keeping the same format, we may want to know what the cell above the one entered looks like.
	my $row_above = $row - 1;
	#If data to put in cell is a mm/dd/yyyy date, format cell accordingly.
	if ( $cell_data =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/ ){
		#Convert to Gnumeric readable integer date.
		my $gnumeric_date = _ss_date_to_num($cell_data);
		#If Gnumeric already had the cell in date format, substitute with the new date, and return.
		if( _get_gnumeric_line_for_cell($column, $row) =~ /(.+Row..$row. Col..$column.+"m\/d\/yyyy">)\d+(<)/ ){
			return $1 . $gnumeric_date . $2;
		}
		#If not, if the cell above is date formatted, create a date cell of the same format as the cell above.
		elsif( _get_gnumeric_line_for_cell($column, $row_above) =~ /(.+Row..)$row_above(. Col..$column.+"m\/d\/yyyy">)\d+(<)/ ){
			return $1 . $row . $2 . $gnumeric_date . $3;
		}
		#Otherwise, return a new date formatted line.
		else{
			#I'm not sure what the ValueType is, hopefully 40 works in all cases.
			return '<gnm:Cell Row="' . $row . '" Col="' . $column . '" ValueType="40" ValueFormat="m/d/yyyy">' . $gnumeric_date . '</gnm:Cell>';
		}
	}
	#Otherwise, write the data into a standard Gnumeric cell.
	else{
		#If a cell already exists, maintain the formatting.
		if( _get_gnumeric_line_for_cell($column, $row) =~ /(.+Row..$row. Col..$column.+>).*(<)/ ){
			return $1 . $cell_data . $2;
		}
		#If not, follow the formatting of the cell above, if it exists.
		elsif( _get_gnumeric_line_for_cell($column, $row_above) =~ /(.+Row..)$row_above(. Col..$column.+>).*(<)/ ){
			return $1 . $row . $2 . $cell_data . $3;
		}
		#Otherwise, write a new Gnumeric line for the new cell.
		#ValueType as 60 may need to be adjusted for certain cell formats here.
		else{
			return "<gnm:Cell Row=\"$row\" Col=\"$column\" ValueType=\"60\">$cell_data</gnm:Cell>";
		}
	}	
}

####################################################
###### Once tested, this could be used for readcell.
####################################################

#Return the XML line from the Gnumeric file that represents the cell one cell above the specified cell.
sub _get_gnumeric_line_for_cell {
	my $cell_column = shift;
	my $cell_row = shift;

	#Go through file until the line representing the cell is found, and return it.
	foreach my $line (@current_working_file){
		if( $line =~ /(.+Row..$cell_row. Col..$cell_column.+)/ ){
			return $1;
		}
	}
	#Otherwise, the cell could not be found, return an empty string.
	return "";
}

#Takes a Gnumeric cell such as and returns XML column/row coordinates
#For example, input of 'E2' will return (4,1).
sub _convert_cell_to_column_and_row_coordinates {
	my $gnumeric_cell = shift;
	die "Could not convert cell input of $gnumeric_cell to row and column coordinates."
		unless $gnumeric_cell =~ /^([A-Za-z]+)(\d+)$/;
	my $letter_column = uc $1;	#Set letters to uppercase to correspond with hash keys.
	#Dereference letter to number using %column_letter_to_number_gnumeric_map
	my $column_coordinate = $column_letter_to_number_gnumeric_map{$letter_column};
	#Rows start at 0 in the gnu spreadsheet; decrement to align.
	my $row_coordinate = $2;
	$row_coordinate--;
	return ($column_coordinate, $row_coordinate);
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
