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

	#Split letter from number
	die "readcell call not executed properly: Failed to split cell index letter from number."
		unless $cell =~ /(\w)(\d+)/;
	my $column = uc $1;	#Set everything to uppercase.
	my $cell_row = $2;
	#Dereference letter to number using %cell_to_gnu_map
	my $cell_column = $cell_to_gnu_map{$column};
	#Rows start at 0 in the gnu spreadsheet; decrement to align.
	$cell_row--;

	# Using an if block filter, read through the current file and return the format found first.
	foreach my $line (@temp_file){
		# The date type of line also has a ValueType and ValueFormat,
		# but no other format has m/d/yyyy format: take it first.
		if( $line =~ /Row..$cell_row. Col..$cell_column.+\"m\/d\/yyyy\"\>(.+)\</ ){
			return _ss_num_to_date( $1 );
		# Take the conditinally formatted cell next.
		}elsif( $line =~ /Row..$cell_row. Col..$cell_column.+ValueFormat..\S+..(.+)\</ ){
			return $1;
		# We've run out of special types; just find the cell and return its contents.
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
	die "readcell call not executed properly: Failed to split cell index letter from number."
		unless $cell =~ /(\w)(\d+)/;
	my $column = uc $1;	#Set everything to uppercase.
	my $cell_row = $2;
	#Dereference letter to number using %cell_to_gnu_map
	my $cell_column = $cell_to_gnu_map{$column};
	#Rows start at 0 in the gnu spreadsheet; decrement to align.
	$cell_row--;
	my $end_gnm_cell_tag = '</gnm:Cell>';
	#Keep track of the current index of the array.
	#foreach (@temp_file){
	for( my $i = 0; $i < scalar @temp_file; $i++){
		my $line = $temp_file[$i];
		if( $line =~ /Row..$cell_row. Col..$cell_column.+\"m\/d\/yyyy\"\>(.*)\</ ){
			die "Data format \"mm/dd/yyy\" expected for this cell."
				unless $data_to_write =~ /^\d\d\/\d\d\/\d\d\d\d$/;
			my $epoch_date = _ss_date_to_num($data_to_write);
			$line =~ s/Row..$cell_row. Col..$cell_column.+\"m\/d\/yyyy\"\>(.*)\</$epoch_date$end_gnm_cell_tag/; 
		}elsif( $line =~ s/Row..$cell_row. Col..$cell_column.+ValueFormat..\S+..(.*)\</$data_to_write$end_gnm_cell_tag/ ){
			#print "Writing conditional cell.\n";
		}elsif( $line =~ s/Row..$cell_row. Col..$cell_column.+ValueType..\d+..(.+)\</$data_to_write$end_gnm_cell_tag/ ){
			#print "Writing nonconditional cell.\n";
		}elsif( $line =~ /\<\/gnm\:Cells\>/ ){
			# Did not find a line to change (cell is empty): create line at the end of gnm:Cell block.
			my $num = $i - 1;
			print "splicing line $num\n";
			splice @temp_file, $num, 0, "<gnm:Cell Row=\"$cell_row\" Col=\"$cell_column\" ValueType=\"60\">$data_to_write</gnm:Cell>";
			$i++;
		}
	}
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
1;
