# !/usr/bin/perl

#-----------------------------------#
# Author: Maude                     #
# Script: mutspecFilter.pl          #
# Last update: 18/03/16             #
#-----------------------------------#

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Basename; # my ($filename, $directories, $suffix) = fileparse($file, qr/\.[^.]*/);
use File::Path;

################################################################################################################################################################################
#																																		Filter an Annotaed file with Annovar																		  																 #
################################################################################################################################################################################

our ($verbose, $man, $help)             = (0, 0, 0);    # Parse options and print usage if there is a syntax error, or if usage was explicitly requested.
our ($dbSNP_value, $segDup, $esp, $thG) = (0, 0, 0, 0); # For filtering agains the databases dbSNP, genomic duplicate segments, Exome Sequencing Project and 1000 genome.
our ($output, $refGenome)               = ("", "");     # The path for saving the result; The reference genome to use.
our ($listAVDB)                         = "empty";      # Text file with the list Annovar databases.
our ($dir)                              = "";

GetOptions('dir|d=s'=>\$dir,'verbose|v'=>\$verbose, 'help|h'=>\$help, 'man|m'=>\$man, 'dbSNP=i'=>\$dbSNP_value, 'segDup'=>\$segDup, 'esp'=>\$esp, 'thG'=>\$thG, 'outfile|o=s' => \$output, 'refGenome=s'=>\$refGenome, 'pathAVDBList=s' => \$listAVDB) or pod2usage(2);

our ($input) = @ARGV;

pod2usage(-verbose=>1, -exitval=>1, -output=>\*STDERR) if ($help);
pod2usage(-verbose=>2, -exitval=>1, -output=>\*STDERR) if ($man);
pod2usage(-verbose=>0, -exitval=>1, -output=>\*STDERR) if(@ARGV == 0); # No argument is pass to the command line print the usage of the script
pod2usage(-verbose=>0, -exitval=>1, -output=>\*STDERR) if(@ARGV == 2); # Only one argument is expected to be pass to @ARGV (the input)



# If the dbSNP value is not equal to zero filter using the dbSNP column specify
our $dbSNP = 0;
if($dbSNP_value > 0) { $dbSNP = 1; }


############ Check flags ############
if($listAVDB eq "empty") { $listAVDB = "$dir/${refGenome}_listAVDB.txt" }

# Zero databases is specified
if( ($dbSNP == 0) && ($segDup == 0) && ($esp == 0) && ($thG == 0) )
{
	print STDERR "There is no databases selected for filtering against!!!\nPlease chose at least one between dbSNP, SegDup, ESP (only for human genome) or 1000 genome (only for human genome)\n";
	exit;
}



############ Recover the name of the databases to filter against ############
my ($segDup_name, $espAll_name, $thousandGenome_name) = ("", "", "");
my @tab_protocol = ();

if( ($segDup == 1) || ($esp == 1) || ($thG == 1) )
{
	### Recover the name of the column
	my $protocol = "";
	ExtractAVDBName($listAVDB, \$protocol);
	@tab_protocol = split(",", $protocol);

	for(my $i=0; $i<=$#tab_protocol; $i++)
	{
		if($tab_protocol[$i] =~ /genomicSuperDups/) { $segDup_name = $tab_protocol[$i]; }
		elsif($tab_protocol[$i] =~ /1000g/)         { $thousandGenome_name = $tab_protocol[$i]; }
		elsif($tab_protocol[$i] =~ /esp/)           { $espAll_name = $tab_protocol[$i]; }
	}
}


############ Filter the file ############
filterAgainstPublicDB();


print STDOUT "\tFilter selected\tdbSNP = ".$dbSNP."\tsegDup = ".$segDup."\tesp = ".$esp."\tthG = ".$thG."\n";


sub filterAgainstPublicDB
{
	open(FILTER, ">", "$output") or die "$!: $output\n";

	open(F1, $input) or die "$!: $input\n";
	my $header = <F1>; print FILTER $header;
	while(<F1>)
	{
		$_      =~ s/[\r\n]+$//;
		my @tab = split("\t", $_);

		my ($segDupInfo, $espAllInfo, $thgInfo) = (0, 0 ,0);

		if($segDup == 1)
		{
			my $segDup_value = recoverNumCol($input, $segDup_name);
			$segDupInfo      = formatSegDupInfo($tab[$segDup_value]);
			# Replace NA by 0 for making test on the same type of variable
			$segDupInfo =~ s/NA/0/;
		}
		if($esp == 1)
		{
			my $espAll_value = recoverNumCol($input, $espAll_name);
			$espAllInfo      = $tab[$espAll_value];
			# Replace NA by 0 for making test on the same type of variable
			$espAllInfo      =~ s/NA/0/;
		}
		if($thG == 1)
		{
			my $thousandGenome_value = recoverNumCol($input, $thousandGenome_name);
			# Replace NA by 0 for making test on the same type of variable
			$thgInfo = $tab[$thousandGenome_value];
			$thgInfo =~ s/NA/0/;
		}


		##############################
		#   			One Filter 				 #
		##############################
		# Remove all the variants present in dbSNP
		if( ($dbSNP == 1) && ($segDup==0) && ($esp==0) && ($thG==0) ) { if($tab[$dbSNP_value-1] eq "NA") { print FILTER "$_\n"; } }
		# Remove all the variants with a frequency greater than or equal to 0.9  in genomic duplicate segments database
		if( ($dbSNP==0) && ($segDup == 1) && ($esp==0) && ($thG==0) ) { if($segDupInfo < 0.9)            { print FILTER "$_\n"; } }
		# Remove all the variants with greater than 0.001 in Exome sequencing project
		if( ($dbSNP==0) && ($segDup==0) && ($esp == 1) && ($thG==0) )    { if($espAllInfo <= 0.001)      { print FILTER "$_\n"; } }
		# Remove all the variants with greater than 0.001 in 1000 genome database
		if( ($dbSNP==0) && ($segDup==0) && ($esp==0) && ($thG == 1) )    { if($thgInfo <= 0.001)         { print FILTER "$_\n"; } }


		#############################
		#   			Two Filter 				 #
		##############################
		if( ($dbSNP==1) && ($segDup==1) && ($esp==0) && ($thG== 0) ) { if( ($tab[$dbSNP_value-1] eq "NA") && ($segDupInfo < 0.9) )    { print FILTER "$_\n"; } }
		if( ($dbSNP==1) && ($segDup==0) && ($esp==1) && ($thG==0) )  { if( ($tab[$dbSNP_value-1] eq "NA") && ($espAllInfo <= 0.001) ) { print FILTER "$_\n"; } }
		if( ($dbSNP==1) && ($segDup==0) && ($esp==0) && ($thG==1) )  { if( ($tab[$dbSNP_value-1] eq "NA") && ($thgInfo <= 0.001) )    { print FILTER "$_\n"; } }

		if( ($dbSNP==0) && ($segDup==1) && ($esp==1) && ($thG==0) )   { if( ($segDupInfo < 0.9) && ($espAllInfo <= 0.001) )           { print FILTER "$_\n"; } }
		if( ($dbSNP==0) && ($segDup==1) && ($esp==0) && ($thG==1) ) { if( ($segDupInfo < 0.9) && ($thgInfo <= 0.001) )                { print FILTER "$_\n"; } }

		if( ($dbSNP==0) && ($segDup==0) && ($esp==1) && ($thG==1) )   { if( ($espAllInfo <= 0.001) && ($thgInfo <= 0.001) )            { print FILTER "$_\n"; } }


		#############################
		#   		Three Filter 				 #
		##############################
		if( ($dbSNP==1) && ($segDup==1) && ($esp==1) && ($thG==0) ) { if( ($tab[$dbSNP_value-1] eq "NA") && ($segDupInfo < 0.9) && ($espAllInfo <= 0.001) )
		{ print FILTER "$_\n"; } }
		if( ($dbSNP==1) && ($segDup==1) && ($esp==0) && ($thG==1) ) { if( ($tab[$dbSNP_value-1] eq "NA") && ($segDupInfo < 0.9) && ($thgInfo <= 0.001) )
		{ print FILTER "$_\n"; } }
		if( ($dbSNP==1) && ($segDup==0) && ($esp==1) && ($thG==1) ) { if( ($tab[$dbSNP_value-1] eq "NA") && ($espAllInfo <= 0.001) && ($thgInfo <= 0.001) )
		{ print FILTER "$_\n"; } }
		if( ($dbSNP==0) && ($segDup==1) && ($esp==1) && ($thG==1) ) { if( ($segDupInfo < 0.9) && ($espAllInfo <= 0.001) && ($thgInfo <= 0.001) )
		{ print FILTER "$_\n"; } }


		#############################
		#   		FOUR Filter 				 #
		##############################
		if( ($dbSNP==1) && ($segDup==1) && ($esp==1) && ($thG==1) ) { if( ($tab[$dbSNP_value-1] eq "NA") && ($segDupInfo < 0.9) && ($espAllInfo <= 0.001) && ($thgInfo <= 0.001) )
		{ print FILTER "$_\n"; } }

	}
	close F1; close FILTER;
}


sub formatSegDupInfo
{
	my ($segDup_info) = @_;

	if($segDup_info ne "NA") # Score=0.907883;Name=chr9:36302931
	{
		my @segDup = split(";", $segDup_info);
		$segDup[0] =~ /Score=(.+)/;
		return $1;
	}
	else { return $segDup_info; }
}


sub ExtractAVDBName
{
	my ($listAVDB, $refS_protocol) = @_;

	open(F1, $listAVDB) or die "$!: $listAVDB\n";
	while(<F1>)
	{
		if ($_ =~ /^#/) { next; }

		$_      =~ s/[\r\n]+$//;
		my @tab = split("\t", $_);

		# db name like refGenome_dbName.txt
		if( ($tab[0] =~ /\w+_(\w+)\.txt/) && ($tab[0] !~ /sites/) && ($tab[0] !~ /esp/) && ($tab[0] !~ /sift/) && ($tab[0] !~ /pp2/) )
		{
			my $temp = $1;
			if($temp =~ /genomicSuperDups/) { $$refS_protocol .= $temp.","; }
		}
		# 1000 genome
		if($tab[0] =~ /sites/)
		{
			$tab[0] =~ /\w+_(\w+)\.sites.(\d+)_(\d+)\.txt/;
			my ($dbName, $year, $month) = ($1, $2, $3);
			$dbName =~ tr/A-Z/a-z/;

			# convert the month number into the month name
			ConvertMonth(\$month);

			my $AVdbName_final = "1000g".$year.$month."_".$dbName;

			if($dbName eq "all") { $$refS_protocol .=$AVdbName_final.","; }
		}
		# ESP
		if($tab[0] =~ /esp/)
		{
			$tab[0] =~ /\w+_(\w+)_(\w+)\.txt/;
			my $AVdbName_final = $1."_".$2;

			if($2 eq "all") { $$refS_protocol .=$AVdbName_final.","; }
		}
	}
	close F1;

	sub ConvertMonth
	{
		my ($refS_month) = @_;

		if($$refS_month == 1)  { $$refS_month = "janv"; }
		elsif($$refS_month == 2)  { $$refS_month = "feb"; }
		elsif($$refS_month == 3)  { $$refS_month = "mar"; }
		elsif($$refS_month == 4)  { $$refS_month = "apr"; }
		elsif($$refS_month == 5)  { $$refS_month = "may"; }
		elsif($$refS_month == 6)  { $$refS_month = "jun"; }
		elsif($$refS_month == 7)  { $$refS_month = "jul"; }
		elsif($$refS_month == 8)  { $$refS_month = "aug"; }
		elsif($$refS_month == 9)  { $$refS_month = "sept"; }
		elsif($$refS_month == 10) { $$refS_month = "oct"; }
		elsif($$refS_month == 11) { $$refS_month = "nov"; }
		elsif($$refS_month == 12) { $$refS_month = "dec"; }
		else { print STDERR "Month number don't considered\n"; exit; }
	}
}


sub recoverNumCol
{
	my ($input, $name_of_column) = @_;

	# With Annovar updates the databases name changed and are present in an array
	if( ref($name_of_column) eq "ARRAY" )
	{
		my $test = "";
		my @tab = @$name_of_column;
		foreach (@tab)
		{
			open(F1,$input) or die "$!: $input\n";
		  # For having the name of the columns
		  my $search_header = <F1>; $search_header =~ s/[\r\n]+$//; my @tab_search_header = split("\t",$search_header);
		  close F1;
		  # The number of the column
		  my $name_of_column_NB  = "toto";
		  for(my $i=0; $i<=$#tab_search_header; $i++)
		  {
		    if($tab_search_header[$i] eq $_) { $name_of_column_NB = $i; }
		  }
		  if($name_of_column_NB eq "toto") { next; }
		  else                             { return $name_of_column_NB; }
		}
		if($name_of_column eq "toto") { print "Error recoverNumCol: the column named $name_of_column doesn't exits in the input file $input!!!!!\n"; exit; }
	}
	# Only one name is pass
	else
	{
		open(FT,$input) or die "$!: $input\n";
	  # For having the name of the columns
	  my $search_header = <FT>; $search_header =~ s/[\r\n]+$//; my @tab_search_header = split("\t",$search_header);
	  close FT;
	  # The number of the column
	  my $name_of_column_NB  = "toto";
	  for(my $i=0; $i<=$#tab_search_header; $i++)
	  {
	    if($tab_search_header[$i] eq $name_of_column) { $name_of_column_NB = $i; }
	  }
	  if($name_of_column_NB eq "toto") { print "Error recoverNumCol: the column named $name_of_column doesn't exits in the input file $input!!!!!\n"; exit; }
	  else                        { return $name_of_column_NB; }
	}
}

=head1 NAME

mutspecFilter - Filter a file annotated with MutSpec-Annot tool. Variants present in public databases (dbSNP, SegDup, ESP, 1000 genome obtained from Annovar) will be removed from the input file (with frequency limits described above)

=head1 SYNOPSIS

	mutspecFilter.pl [arguments] <query-file>

  <query-file>                                   an annotated file

  Arguments:
        -h,        --help                        print help message
        -m,        --man                         print complete documentation
        -v,        --verbose                     use verbose output
									 --dbSNP <value>               filter against dbSNP database. Specify the number of the dbSNP column in the file
									 --segDup                      filter against genomic duplicate database
									 --esp                         filter against Exome Sequencing Project database (only for human)
									 --thG                         filter against 1000 genome database (onyl for human)
			  -o,        --outfile <string>            name of output file
			             --refGenome                   reference genome to use
			             --pathAVDBList                path to the list of Annovar databases installed


Function: Filter out variants present in public databases

 Example: # Filter against dbSNP
 					mutspecFilter.pl --dbSNP col_number --refGenome hg19 --pathAVDBList path_to_the_list_of_annovar_DB --outfile output_filename input

 					# Filter against the four databases
 					mutspecFilter.pl --dbSNP col_number --segDup --esp --thG --refGenome hg19 --pathAVDBList path_to_the_list_of_annovar_DB --outfile output_filename input


 Version: 03-2016 (March 2016)


=head1 OPTIONS

=over 8

=item B<--help>

print a brief usage message and detailed explanation of options.

=item B<--man>

print the complete manual of the program.

=item B<--verbose>

use verbose output.

=item B<--dbSNP>

Remove all the variants presents in the dbSNP databases
Specify the number of column containing the annotation
For human and mouse genome

=item B<--segDup>

Remove all the variants with a frequency greater or equal to 0.9 in genomic duplicate segments database
For human and mouse genome

=item B<--esp>

Remove all the variants with a frequency greater than 0.001 in Exome sequencing project
For human genome only

=item B<--thG>

Remove all the variants with a frequency greater than 0.001 in 1000 genome database

=item B<--refGenome>

the reference genome to use, could be hg19 or mm9.

=item B<--outfile>

the name of the output file

=item B<--pathAVDBList>

the path to a texte file containing the list of the Annovar databases installed.

=back

=head1 DESCRIPTION

mutspecFilter - Filter a file annotated with MutSpec-Annot tool. Variants present in public databases (dbSNP, SegDup, ESP, 1000 genome obtained from Annovar) will be removed from the input file (with frequency limits described above)

=cut
