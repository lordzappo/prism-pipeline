#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use IPC::Open3;
use File::Spec;
use File::Basename;
use Cwd;

## This program is Copyright (C) 2012, Felix Krueger (felix.krueger@babraham.ac.uk)

## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.

## You should have received a copy of the GNU General Public License
## along with this program. If not, see <http://www.gnu.org/licenses/>.



## this script is taking in FastQ sequences and trims them with Cutadapt
## last modified on 18 10 2012

########################################################################

# change these paths if needed

my $path_to_cutadapt = '/usr/bin/cutadapt';
my $path_to_fastqc = '/usr/bin/fastqc';


########################################################################


my $trimmer_version = '0.2.5';
my $DOWARN = 1; # print on screen warning and text by default
BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN } };

my ($cutoff,$adapter,$stringency,$rrbs,$length_cutoff,$keep,$fastqc,$non_directional,$phred_encoding,$fastqc_args,$trim,$gzip,$validate,$retain,$length_read_1,$length_read_2,$a2,$error_rate,$output_dir,$no_report_file) = process_commandline();

### SETTING DEFAULTS UNLESS THEY WERE SPECIFIED
unless (defined $cutoff){
  $cutoff = 20;
}
my $phred_score_cutoff = $cutoff; # only relevant for report

unless (defined $adapter){
  $adapter = 'AGATCGGAAGAGC';
}
unless (defined $a2){ # optional adapter for the second read in a pair. Only works for --paired trimming
  $a2 = '';
}

unless (defined $stringency){
  $stringency = 1;
}

unless (defined $length_cutoff){
  $length_cutoff = 20;
}

if ($phred_encoding == 64){
  $cutoff += 31;
}

my @filenames = @ARGV;

my $file_1;
my $file_2;

foreach my $filename (@ARGV){
  trim ($filename);
}


sub trim{
  my $filename = shift;

  my $output_filename = (split (/\//,$filename))[-1];
  # warn "Here is the outputfile name: $output_filename\n";

  my $report = $output_filename;
  $report =~ s/\.fastq\.gz$/_cl.stats/;

  if ($no_report_file) {
    $report = File::Spec->devnull;
    open (REPORT,'>',$report) or die "Failed to write to file: $!\n";
    # warn "Redirecting report output to /dev/null\n";
  }
  else{
    open (REPORT,'>',$output_dir.$report) or die "Failed to write to file: $!\n";
    warn "Writing report to '$output_dir$report'\n";
  }

  warn "\nSUMMARISING RUN PARAMETERS\n==========================\nInput filename: $filename\n";
  print REPORT "\nSUMMARISING RUN PARAMETERS\n==========================\nInput filename: $filename\n";

  warn "Quality Phred score cutoff: $phred_score_cutoff\n";
  print REPORT "Quality Phred score cutoff: $phred_score_cutoff\n";

  warn "Quality encoding type selected: ASCII+$phred_encoding\n";
  print REPORT "Quality encoding type selected: ASCII+$phred_encoding\n";

  warn "Adapter sequence: '$adapter'\n";
  print REPORT "Adapter sequence: '$adapter'\n";

  if ($error_rate == 0.1){
    warn "Maximum trimming error rate: $error_rate (default)\n";
  }
  else{
    warn "Maximum trimming error rate: $error_rate\n";
  }

  print REPORT "Maximum trimming error rate: $error_rate";
  if ($error_rate == 0.1){
    print REPORT " (default)\n";
  }
  else{
    print REPORT "\n";
  }

  if ($a2){
    warn "Optional adapter 2 sequence (only used for read 2 of paired-end files): '$a2'\n";
    print REPORT "Optional adapter 2 sequence (only used for read 2 of paired-end files): '$a2'\n";
  }

  warn "Minimum required adapter overlap (stringency): $stringency bp\n";
  print REPORT "Minimum required adapter overlap (stringency): $stringency bp\n";

  if ($validate){
    warn "Minimum required sequence length for both reads before a sequence pair gets removed: $length_cutoff bp\n";
    print REPORT "Minimum required sequence length for both reads before a sequence pair gets removed: $length_cutoff bp\n";
  }
  else{
    warn "Minimum required sequence length before a sequence gets removed: $length_cutoff bp\n";
    print REPORT "Minimum required sequence length before a sequence gets removed: $length_cutoff bp\n";
  }

  if ($validate){ # only for paired-end files

    if ($retain){ # keeping single-end reads if only one end is long enough

      if ($length_read_1 == 35){
	warn "Length cut-off for read 1: $length_read_1 bp (default)\n";
	print REPORT "Length cut-off for read 1: $length_read_1 bp (default)\n";
      }
      else{
	warn "Length cut-off for read 1: $length_read_1 bp\n";
	print REPORT "Length cut-off for read 1: $length_read_1 bp\n";
      }

      if ($length_read_2 == 35){
	warn "Length cut-off for read 2: $length_read_2 b (default)\n";
	print REPORT "Length cut-off for read 2: $length_read_2 bp (default)\n";
      }
      else{
	warn "Length cut-off for read 2: $length_read_2 bp\n";
	print REPORT "Length cut-off for read 2: $length_read_2 bp\n";
      }
    }
  }

  if ($rrbs){
    warn "File was specified to be an MspI-digested RRBS sample. Sequences with adapter contamination will be trimmed a further 2 bp to remove potential methylation-biased bases from the end-repair reaction\n";
    print REPORT "File was specified to be an MspI-digested RRBS sample. Sequences with adapter contamination will be trimmed a further 2 bp to remove potential methylation-biased bases from the end-repair reaction\n";
  }

  if ($non_directional){
    warn "File was specified to be a non-directional MspI-digested RRBS sample. Sequences starting with either 'CAA' or 'CGA' will have the first 2 bp trimmed off to remove potential methylation-biased bases from the end-repair reaction\n";
    print REPORT "File was specified to be a non-directional MspI-digested RRBS sample. Sequences starting with either 'CAA' or 'CGA' will have the first 2 bp trimmed off to remove potential methylation-biased bases from the end-repair reaction\n";
  }

  if ($trim){
    warn "All sequences will be trimmed by 1 bp on their 3' end to avoid problems with invalid paired-end alignments with Bowtie 1\n";
    print REPORT "All sequences will be trimmed by 1 bp on their 3' end to avoid problems with invalid paired-end alignments with Bowtie 1\n";
  }

  if ($fastqc){
    warn "Running FastQC on the data once trimming has completed\n";
    print REPORT "Running FastQC on the data once trimming has completed\n";

    if ($fastqc_args){
      warn "Running FastQC with the following extra arguments: '$fastqc_args'\n";
      print REPORT  "Running FastQC with the following extra arguments: $fastqc_args\n";
    }
  }

  if ($keep and $rrbs){
    warn "Keeping quality trimmed (but not yet adapter trimmed) intermediate FastQ file\n";
    print REPORT "Keeping quality trimmed (but not yet adapter trimmed) intermediate FastQ file\n";
  }

  if ($gzip or $filename =~ /\.gz$/){
    warn "Output file will be GZIP compressed\n";
    print REPORT "Output file will be GZIP compressed\n";
  }

  warn "\n";
  print REPORT "\n";
  sleep (3);

  my $temp;

  ### Proceeding differently for RRBS and other type of libraries
  if ($rrbs){

    ### Skipping quality filtering for RRBS libraries if a quality cutoff of 0 was specified
    if ($cutoff == 0){
      warn "Quality cutoff selected was 0    -    Skipping quality trimming altogether\n\n";
      sleep (3);
    }
    else{

      $temp = $filename;
      $temp =~ s/$/_qual_trimmed.fastq/;
      open (TEMP,'>',$output_dir.$temp) or die "Can't write to $temp: $!";

      warn "  >>> Now performing adaptive quality trimming with a Phred-score cutoff of: $cutoff <<<\n\n";
      sleep (3);

      open (QUAL,"$path_to_cutadapt -f fastq -e $error_rate -q $cutoff -a X $filename |") or die "Can't open pipe to Cutadapt: $!";

      my $qual_count = 0;

      while (1){
	my $l1 = <QUAL>;
	my $seq = <QUAL>;
	my $l3 = <QUAL>;
	my $qual = <QUAL>;
	last unless (defined $qual);
	
	$qual_count++;
	if ($qual_count%10000000 == 0){
	  warn "$qual_count sequences processed\n";
	}
	print TEMP "$l1$seq$l3$qual";
      }

      warn "\n  >>> Quality trimming completed <<<\n$qual_count sequences processed in total\n\n";
      close QUAL or die "Unable to close filehandle: $!\n";
      sleep (3);

    }
  }


  if ($output_filename =~ /\.fastq$/){
    $output_filename =~ s/\.fastq$/_trimmed.fq/;
  }
  elsif ($output_filename =~ /\.fastq\.gz$/){
    $output_filename =~ s/\.fastq\.gz$/_trimmed.fq/;
  }
  elsif ($output_filename =~ /\.fq$/){
    $output_filename =~ s/\.fq$/_trimmed.fq/;
  }
  elsif ($output_filename =~ /\.fq\.gz$/){
    $output_filename =~ s/\.fq\.gz$/_trimmed.fq/;
  }
  else{
    $output_filename =~ s/$/_trimmed.fq/;
  }

  warn "Writing final adapter and quality trimmed output to $output_filename\n\n";
  open (OUT,'>',$output_dir.$output_filename) or die "Can't open $output_filename: $!\n";
  sleep (2);

  my $count = 0;
  my $too_short = 0;
  my $quality_trimmed = 0;
  my $rrbs_trimmed = 0;
  my $rrbs_trimmed_start = 0;
  my $CAA = 0;
  my $CGA = 0;

  if ($rrbs and $cutoff != 0){

    ### optionally using 2 different adapters for read 1 and read 2
    if ($validate and $a2){
      ### Figure out whether current file counts as read 1 or read 2 of paired-end files
      if ( scalar(@filenames)%2 == 0){ # this is read 1 of a pair
	warn "\n  >>> Now performing adapter trimming for the adapter sequence: '$adapter' from file $temp <<< \n";
	sleep (3);
	open3 (\*WRITER, \*TRIM, \*ERROR,"$path_to_cutadapt -f fastq -e $error_rate -O $stringency -a $adapter $output_dir$temp") or die "Failed to launch Cutadapt: $!\n";
      }
      else{                            # this is read 2 of a pair
	warn "\n  >>> Now performing adapter trimming for the adapter sequence: '$a2' from file $temp <<< \n";
	sleep (3);
    	open3 (\*WRITER, \*TRIM, \*ERROR,"$path_to_cutadapt -f fastq -e $error_rate -O $stringency -a $a2 $output_dir$temp") or die "Failed to launch Cutadapt: $!\n";
      }
    }
    ### Using the same adapter for both read 1 and read 2
    else{
      warn "\n  >>> Now performing adapter trimming for the adapter sequence: '$adapter' from file $temp <<< \n";
      sleep (3);
      open3 (\*WRITER, \*TRIM, \*ERROR,"$path_to_cutadapt -f fastq -e $error_rate -O $stringency -a $adapter $output_dir$temp") or die "Failed to launch Cutadapt: $!\n";
    }

    close WRITER or die $!; # not needed

    open (QUAL,"$output_dir$temp") or die $!; # quality trimmed file

    if ($filename =~ /\.gz$/){
      open (IN,"zcat $filename |") or die $!; # original, untrimmed file
    }
    else{
      open (IN,$filename) or die $!; # original, untrimmed file
    }

    while (1){

      # we can process the output from Cutadapt and the original input 1 by 1 to decide if the adapter has been removed or not
      my $l1 = <TRIM>;
      my $seq = <TRIM>; # adapter trimmed sequence
      my $l3 = <TRIM>;
      my $qual = <TRIM>;

      $_ = <IN>;   # irrelevant
      my $original_seq = <IN>;
      $_ = <IN>;   # irrelevant
      $_ = <IN>;   # irrelevant

      $_ = <QUAL>; # irrelevant
      my $qual_trimmed_seq = <QUAL>;
      $_ = <QUAL>; # irrelevant
      my $qual_trimmed_qual = <QUAL>;

      last unless (defined $qual and defined $qual_trimmed_qual); # could be empty strings

      $count++;
      if ($count%10000000 == 0){
	warn "$count sequences processed\n";
      }

      chomp $seq;
      chomp $qual;
      chomp $qual_trimmed_seq;
      chomp $original_seq;

      my $quality_trimmed_seq_length = length $qual_trimmed_seq;

      if (length $original_seq > length $qual_trimmed_seq){
	++$quality_trimmed;
      }

      my $nd = 0;

      ### NON-DIRECTIONAL RRBS
      if ($non_directional){
	if (length$seq > 2){
	  if ($seq =~ /^CAA/){
	    ++$CAA;
	    $seq = substr ($seq,2,length($seq)-2);
	    $qual = substr ($qual,2,length($qual)-2);
	    ++$rrbs_trimmed_start;
	    $nd = 1;
	  }
	  elsif ($seq =~ /^CGA/){
	    $seq = substr ($seq,2,length($seq)-2);
	    $qual = substr ($qual,2,length($qual)-2);
	    ++$CGA;
	    ++$rrbs_trimmed_start;
	    $nd = 1;
	  }
	}
      }

      ### directional read
      unless ($nd == 1){
	if (length $seq >= 2 and length$seq < $quality_trimmed_seq_length){
	  $seq = substr ($seq,0,length($seq)-2);
	  $qual = substr ($qual,0,length($qual)-2);
	  ++$rrbs_trimmed;
	}
      }

      ### Shortening all sequences by 1 bp on the 3' end
      if ($trim){
	$seq = substr($seq,0,length($seq)-1);
	$qual = substr($qual,0,length($qual)-1);
      }

      ### PRINTING (POTENTIALLY TRIMMED) SEQUENCE
      if ($validate){ # printing the sequence without performing a length check (this is performed for the read pair separately later)
	print OUT "$l1$seq\n$l3$qual\n";
      }
      else{ # single end
	if (length $seq < $length_cutoff){
	  ++$too_short;
	  next;
	}
	else{
	  print OUT "$l1$seq\n$l3$qual\n";
	}
      }
    }

    print REPORT "\n";
    while (<ERROR>){
      warn $_;
      print REPORT $_;
    }

    close IN or die "Unable to close IN filehandle: $!";
    close QUAL or die "Unable to close QUAL filehandle: $!";
    close TRIM or die "Unable to close TRIM filehandle: $!";
    close OUT or die  "Unable to close OUT filehandle: $!";
  }
  else{

    ### optionally using 2 different adapters for read 1 and read 2
    if ($validate and $a2){
      ### Figure out whether current file counts as read 1 or read 2 of paired-end files
      if ( scalar(@filenames)%2 == 0){ # this is read 1 of a pair
	warn "\n  >>> Now performing quality (cutoff $cutoff) and adapter trimming in a single pass for the adapter sequence: '$adapter' from file $filename <<< \n";
	sleep (3);
	open3 (\*WRITER, \*TRIM, \*ERROR, "$path_to_cutadapt -f fastq -e $error_rate -q $cutoff -O $stringency -a $adapter $filename") or die "Failed to launch Cutadapt: $!";
      }
      else{                            # this is read 2 of a pair
	warn "\n  >>> Now performing quality (cutoff $cutoff) and adapter trimming in a single pass for the adapter sequence: '$a2' from file $filename <<< \n";
	sleep (3);
	open3 (\*WRITER, \*TRIM, \*ERROR, "$path_to_cutadapt -f fastq -e $error_rate -q $cutoff -O $stringency -a $a2 $filename") or die "Failed to launch Cutadapt: $!";
      }
    }
    ### Using the same adapter for both read 1 and read 2
    else{
      warn "\n  >>> Now performing quality (cutoff $cutoff) and adapter trimming in a single pass for the adapter sequence: '$adapter' from file $filename <<< \n";
      sleep (3);
      open3 (\*WRITER, \*TRIM, \*ERROR, "$path_to_cutadapt -f fastq -e $error_rate -q $cutoff -O $stringency -a $adapter $filename") or die "Failed to launch Cutadapt: $!";
    }

    close WRITER or die $!; # not needed

    while (1){

      my $l1 = <TRIM>;
      my $seq = <TRIM>; # quality and/or adapter trimmed sequence
      my $l3 = <TRIM>;
      my $qual = <TRIM>;
      # print "$l1$seq\n$l3$qual\n";
      last unless (defined $qual); # could be an empty string

      $count++;
      if ($count%10000000 == 0){
	warn "$count sequences processed\n";
      }

      chomp $seq;
      chomp $qual;

      ### Shortening all sequences by 1 bp on the 3' end
      if ($trim){
	$seq = substr($seq,0,length($seq)-1);
	$qual = substr($qual,0,length($qual)-1);
      }

      ### PRINTING (POTENTIALLY TRIMMED) SEQUENCE
      if ($validate){ # printing the sequence without performing a length check (this is performed for the read pair separately later)
	print OUT "$l1$seq\n$l3$qual\n";
      }
      else{ # single end
	if (length $seq < $length_cutoff){
	  ++$too_short;
	  next;
	}
	else{
	  print OUT "$l1$seq\n$l3$qual\n";
	}
      }
    }

    print REPORT "\n";
    while (<ERROR>){
      warn $_;
      print REPORT $_;
    }

    close TRIM or die "Unable to close TRIM filehandle: $!\n";
    close ERROR or die "Unable to close ERROR filehandle: $!\n";
    close OUT or die  "Unable to close OUT filehandle: $!\n";

  }

  if ($rrbs){
    unless ($keep){ # keeping the quality trimmed intermediate file for RRBS files

      # deleting temporary quality trimmed file
      my $deleted = unlink "$output_dir$temp";

      if ($deleted){
	warn "Successfully deleted temporary file $temp\n\n";
      }
      else{
	warn "Could not delete temporary file $temp";
      }
    }
  }

  warn "\nRUN STATISTICS FOR INPUT FILE: $filename\n";
  print REPORT "\nRUN STATISTICS FOR INPUT FILE: $filename\n";

  warn "="x 45,"\n";
  print REPORT "="x 45,"\n";

  warn "$count sequences processed in total\n";
  print REPORT "$count sequences processed in total\n";

  ###  only reporting this separately if quality and adapter trimming were performed separately
  if ($rrbs){
    my $percentage_shortened = sprintf ("%.1f",$quality_trimmed/$count*100);
    warn "Sequences were truncated to a varying degree because of deteriorating qualities (Phred score quality cutoff: $cutoff):\t$quality_trimmed ($percentage_shortened%)\n";
    print REPORT "Sequences were truncated to a varying degree because of deteriorating qualities (Phred score quality cutoff: $cutoff):\t$quality_trimmed ($percentage_shortened%)\n";
  }

  my $percentage_too_short = sprintf ("%.1f",$too_short/$count*100);
  warn "Sequences removed because they became shorter than the length cutoff of $length_cutoff bp:\t$too_short ($percentage_too_short%)\n";
  print REPORT "Sequences removed because they became shorter than the length cutoff of $length_cutoff bp:\t$too_short ($percentage_too_short%)\n";

  if ($rrbs){
    my $percentage_rrbs_trimmed = sprintf ("%.1f",$rrbs_trimmed/$count*100);
    warn "RRBS reads trimmed by additional 2 bp when adapter contamination was detected:\t$rrbs_trimmed ($percentage_rrbs_trimmed%)\n";
    print REPORT "RRBS reads trimmed by additional 2 bp when adapter contamination was detected:\t$rrbs_trimmed ($percentage_rrbs_trimmed%)\n";
  }

  if ($non_directional){
    my $percentage_rrbs_trimmed_at_start = sprintf ("%.1f",$rrbs_trimmed_start/$count*100);
    warn "RRBS reads trimmed by 2 bp at the start when read started with CAA ($CAA) or CGA ($CGA) in total:\t$rrbs_trimmed_start ($percentage_rrbs_trimmed_at_start%)\n";
    print REPORT "RRBS reads trimmed by 2 bp at the start when read started with CAA ($CAA) or CGA ($CGA) in total:\t$rrbs_trimmed_start ($percentage_rrbs_trimmed_at_start%)\n";
  }

  warn "\n";
  print REPORT "\n";

  ### RUNNING FASTQC
  if ($fastqc){
    warn "\n  >>> Now running FastQC on the data <<<\n\n";
    sleep (5);
    if ($fastqc_args){
      system ("$path_to_fastqc $fastqc_args $output_filename");
    }
    else{
      system ("$path_to_fastqc $output_filename");
    }
  }

  ### COMPRESSING OUTPUT FILE
  unless ($validate){ # not gzipping intermediate files for paired-end files
    if ($gzip or $filename =~ /\.gz$/){
      warn "\n  >>> GZIP-ing the output file <<<\n\n";
      system ("gzip -f $output_filename");
      $output_filename = $output_filename.'.gz';
    }
  }

  ### VALIDATE PAIRED-END FILES
  if ($validate){

    ### Figure out whether current file counts as read 1 or read 2 of paired-end files

    if ( scalar(@filenames)%2 == 0){ # this is read 1 of a pair
      $file_1 = $output_filename;
      shift @filenames;
      # warn "This is read 1: $file_1\n\n";
    }
    else{                            # this is read 2 of a pair
      $file_2 = $output_filename;
      shift @filenames;
      # warn "This is read 2: $file_2\n\n";
    }

    if ($file_1 and $file_2){
      warn "Validate paired-end files $file_1 and $file_2\n";
      sleep (1);

      my ($val_1,$val_2,$un_1,$un_2) = validate_paired_end_files($file_1,$file_2);

      ### RUNNING FASTQC
      if ($fastqc){

	warn "\n  >>> Now running FastQC on the validated data $val_1<<<\n\n";
	sleep (3);

	if ($fastqc_args){
	  system ("$path_to_fastqc $fastqc_args $val_1");
	}
	else{
	  system ("$path_to_fastqc $val_1");
	}

	warn "\n  >>> Now running FastQC on the validated data $val_2<<<\n\n";
	sleep (3);

	if ($fastqc_args){
	  system ("$path_to_fastqc $fastqc_args $val_2");
	}
	else{
	  system ("$path_to_fastqc $val_2");
	}
	
      }

      if ($gzip or $filename =~ /\.gz$/){
		
	# compressing main fastQ output files
	warn "Compressing the validated output file $val_1 ...\n";
	system ("gzip -f $val_1");
	
	warn "Compressing the validated output file $val_2 ...\n";
	system ("gzip -f $val_2");


	if ($retain){ # compressing unpaired reads
	  warn "Compressing the unpaired read output $un_1 ...\n";
	  system ("gzip -f $un_1");
	
	  warn "Compressing the unpaired read output $un_2 ...\n";
	  system ("gzip -f $un_2");
	}
      }

      warn "Deleting both intermediate output files $file_1 and $file_2\n";
      unlink "$output_dir$file_1";
      unlink "$output_dir$file_2";

      warn "\n",'='x100,"\n\n";
      sleep (3);

      $file_1 = undef; # setting file_1 and file_2 to undef once validation is completed
      $file_2 = undef;
    }
  }

}

sub validate_paired_end_files{

  my $file_1 = shift;
  my $file_2 = shift;

  warn "file_1 $file_1 file_2 $file_2\n\n";

  if ($file_1 =~ /\.gz$/){
    open (IN1,"zcat $output_dir$file_1 |") or die "Couldn't read from file $file_1: $!\n";
  }
  else{
    open (IN1, "$output_dir$file_1") or die "Couldn't read from file $file_1: $!\n";
  }

  if ($file_2 =~ /\.gz$/){
    open (IN2,"zcat $output_dir$file_2 |") or die "Couldn't read from file $file_2: $!\n";
  }
  else{
    open (IN2, "$output_dir$file_2") or die "Couldn't read from file $file_2: $!\n";
  }

  warn "\n>>>>> Now validing the length of the 2 paired-end infiles: $file_1 and $file_2 <<<<<\n";
  sleep (3);

  my $out_1 = $file_1;
  my $out_2 = $file_2;

  if ($out_1 =~ /gz$/){
    $out_1 =~ s/_trimmed\.fq\.gz$/_cl.fastq/;
  }
  else{
    $out_1 =~ s/_trimmed\.fq$/_cl.fastq/;
  }

  if ($out_2 =~ /gz$/){
    $out_2 =~ s/_trimmed\.fq\.gz$/_cl.fastq/;
  }
  else{
    $out_2 =~ s/_trimmed\.fq$/_cl.fastq/;
  }

  open (R1,'>',$output_dir.$out_1) or die "Couldn't write to $out_1 $!\n";
  open (R2,'>',$output_dir.$out_2) or die "Couldn't write to $out_2 $!\n";
  warn "Writing validated paired-end read 1 reads to $out_1\n";
  warn "Writing validated paired-end read 2 reads to $out_2\n\n";

  my $unpaired_1;
  my $unpaired_2;

  if ($retain){

    $unpaired_1 = $file_1;
    $unpaired_2 = $file_2;

    if ($unpaired_1 =~ /gz$/){
      $unpaired_1 =~ s/trimmed\.fq\.gz$/-unpaired_1.fastq/;
    }
    else{
      $unpaired_1 =~ s/trimmed\.fq$/-unpaired_1.fastq/;
    }

    if ($unpaired_2 =~ /gz$/){
      $unpaired_2 =~ s/trimmed\.fq\.gz$/-unpaired_2.fastq/;
    }
    else{
      $unpaired_2 =~ s/trimmed\.fq$/-unpaired_2.fastq/;
    }

    open (UNPAIRED1,'>',$output_dir.$unpaired_1) or die "Couldn't write to $unpaired_1: $!\n";
    open (UNPAIRED2,'>',$output_dir.$unpaired_2) or die "Couldn't write to $unpaired_2: $!\n";

    warn "Writing unpaired read 1 reads to $unpaired_1\n";
    warn "Writing unpaired read 2 reads to $unpaired_2\n\n";
  }

  my $sequence_pairs_removed = 0;
  my $read_1_printed = 0;
  my $read_2_printed = 0;

  my $count = 0;

  while (1){
    my $id_1   = <IN1>;
    my $seq_1  = <IN1>;
    my $l3_1   = <IN1>;
    my $qual_1 = <IN1>;
    last unless ($id_1 and $seq_1 and $l3_1 and $qual_1);

    my $id_2   = <IN2>;
    my $seq_2  = <IN2>;
    my $l3_2   = <IN2>;
    my $qual_2 = <IN2>;
    last unless ($id_2 and $seq_2 and $l3_2 and $qual_2);

    ++$count;


    ## small check if the sequence files appear to FastQ files
    if ($count == 1){ # performed just once
      if ($id_1 !~ /^\@/ or $l3_1 !~ /^\+/){
	die "Input file doesn't seem to be in FastQ format at sequence $count\n";
      }
      if ($id_2 !~ /^\@/ or $l3_2 !~ /^\+/){
	die "Input file doesn't seem to be in FastQ format at sequence $count\n";
      }
    }

    chomp $seq_1;
    chomp $seq_2;


    ### making sure that the reads do have a sensible length
    if ( (length($seq_1) < $length_cutoff) or (length($seq_2) < $length_cutoff) ){
      ++$sequence_pairs_removed;
      if ($retain){ # writing out single-end reads if they are longer than the cutoff
	
	if ( length($seq_1) >= $length_read_1){ # read 1 is long enough
	  print UNPAIRED1 $id_1;
	  print UNPAIRED1 "$seq_1\n";
	  print UNPAIRED1 $l3_1;
	  print UNPAIRED1 $qual_1;
	  ++$read_1_printed;
	}
	
	if ( length($seq_2) >= $length_read_2){ # read 2 is long enough
	  print UNPAIRED2 $id_2;
	  print UNPAIRED2 "$seq_2\n";
	  print UNPAIRED2 $l3_2;
	  print UNPAIRED2 $qual_2;
	  ++$read_2_printed;
	}
	
      }
    }
    else{
      print R1 $id_1;
      print R1 "$seq_1\n";
      print R1 $l3_1;
      print R1 $qual_1;

      print R2 $id_2;
      print R2 "$seq_2\n";
      print R2 $l3_2;
      print R2 $qual_2;
    }

  }
  my $percentage = sprintf("%.2f",$sequence_pairs_removed/$count*100);
  warn "Total number of sequences analysed: $count\n\n";
  warn "Number of sequence pairs removed: $sequence_pairs_removed ($percentage%)\n";

  print REPORT "Total number of sequences analysed for the sequence pair length validation: $count\n\n";
  print REPORT "Number of sequence pairs removed because at least one read was shorter than the length cutoff ($length_cutoff bp): $sequence_pairs_removed ($percentage%)\n";

  if ($keep){
    warn "Number of unpaired read 1 reads printed: $read_1_printed\n";
    warn "Number of unpaired read 2 reads printed: $read_2_printed\n";
  }

  warn "\n";
  if ($retain){
    return ($out_1,$out_2,$unpaired_1,$unpaired_2);
  }
  else{
    return ($out_1,$out_2);
  }
}

sub process_commandline{
  my $help;
  my $quality;
  my $adapter;
  my $adapter2;
  my $stringency;
  my $report;
  my $version;
  my $rrbs;
  my $length_cutoff;
  my $keep;
  my $fastqc;
  my $non_directional;
  my $phred33;
  my $phred64;
  my $fastqc_args;
  my $trim;
  my $gzip;
  my $validate;
  my $retain;
  my $length_read_1;
  my $length_read_2;
  my $error_rate;
  my $output_dir;
  my $no_report_file;
  my $suppress_warn;

  my $command_line = GetOptions ('help|man' => \$help,
				 'q|quality=i' => \$quality,
				 'a|adapter=s' => \$adapter,
				 'a2|adapter2=s' => \$adapter2,
				 'report' => \$report,
				 'version' => \$version,
				 'stringency=i' => \$stringency,
				 'fastqc' => \$fastqc,
				 'RRBS' => \$rrbs,	
				 'keep' => \$keep,
				 'length=i' => \$length_cutoff,
				 'non_directional' => \$non_directional,
				 'phred33' => \$phred33,
				 'phred64' => \$phred64,
				 'fastqc_args=s' => \$fastqc_args,
				 'trim1' => \$trim,
				 'gzip' => \$gzip,
				 'paired_end' => \$validate,
				 'retain_unpaired' => \$retain,
				 'length_1|r1=i' => \$length_read_1,
				 'length_2|r2=i' => \$length_read_2,
				 'e|error_rate=s' => \$error_rate,
				 'o|output_dir=s' => \$output_dir,
				 'no_report_file' => \$no_report_file,
				 'suppress_warn' => \$suppress_warn,
				);
  
  ### EXIT ON ERROR if there were errors with any of the supplied options
  unless ($command_line){
    die "Please respecify command line options\n";
  }

  ### HELPFILE
  if ($help){
    print_helpfile();
    exit;
  }




  if ($version){
    print << "VERSION";

                          Quality-/Adapter-/RRBS-Trimming
                               (powered by Cutadapt)
                                  version $trimmer_version

                             Last update: 18 10 2012

VERSION
    exit;
  }

  ### RRBS
  unless ($rrbs){
    $rrbs = 0;
  }

  ### SUPRESS WARNINGS
  if (defined $suppress_warn){
    $DOWARN = 0;
  }

  ### QUALITY SCORES
  my $phred_encoding;
  if ($phred33){
    if ($phred64){
      die "Please specify only a single quality encoding type (--phred33 or --phred64)\n\n";
    }
    $phred_encoding = 33;
  }
  elsif ($phred64){
    $phred_encoding = 64;
  }
  unless ($phred33 or $phred64){
    warn "No quality encoding type selected. Assuming that the data provided uses Sanger encoded Phred scores (default)\n\n";
    $phred_encoding = 33;
    sleep (3);
  }

  ### NON-DIRECTIONAL RRBS
  if ($non_directional){
    unless ($rrbs){
      die "Option '--non_directional' requires '--rrbs' to be specified as well. Please re-specify!\n";
    }
  }
  else{
    $non_directional = 0;
  }

  if ($fastqc_args){
    $fastqc = 1; # specifying fastqc extra arguments automatically means that FastQC will be executed
  }
  else{
    $fastqc_args = 0;
  }

  ### CUSTOM ERROR RATE
  if (defined $error_rate){
    # make sure that the error rate is between 0 and 1
    unless ($error_rate >= 0 and $error_rate <= 1){
      die "Please specify an error rate between 0 and 1 (the default is 0.1)\n";
    }
  }
  else{
    $error_rate = 0.1; # (default)
  }

  if (defined $adapter){
    unless ($adapter =~ /^[ACTGNactgn]+$/){
      #die "Adapter sequence must contain DNA characters only (A,C,T,G or N)!\n";
    }
    $adapter = uc$adapter;
  }

  if (defined $adapter2){
    unless ($validate){
      die "An optional adapter for read 2 of paired-end files requires '--paired' to be specified as well! Please re-specify\n";
    }
    unless ($adapter2 =~ /^[ACTGNactgn]+$/){
      #die "Optional adapter 2 sequence must contain DNA characters only (A,C,T,G or N)!\n";
    }
    $adapter2 = uc$adapter2;
  }

  ### files are supposed to be paired-end files
  if ($validate){

    # making sure that an even number of reads has been supplied
    unless ((scalar@ARGV)%2 == 0){
      die "Please provide an even number of input files for paired-end FastQ trimming! Aborting ...\n";
    }

    ## CUTOFF FOR VALIDATED READ-PAIRS

    if (defined $length_read_1 or defined $length_read_2){
      unless ($retain){
	die "Please specify --keep_unpaired to alter the unpaired single-end read length cut off(s)\n\n";
      }

      if (defined $length_read_1){
	unless ($length_read_1 >= 15 and $length_read_1 <= 100){
	  die "Please select a sensible cutoff for when a read pair should be filtered out due to short length (allowed range: 15-100 bp)\n\n";
	}
	unless ($length_read_1 > $length_cutoff){
	  die "The single-end unpaired read length needs to be longer than the paired-end cut-off value\n\n";
	}
      }

      if (defined $length_read_2){
	unless ($length_read_2 >= 15 and $length_read_2 <= 100){
	  die "Please select a sensible cutoff for when a read pair should be filtered out due to short length (allowed range: 15-100 bp)\n\n";
	}
	unless ($length_read_2 > $length_cutoff){
	  die "The single-end unpaired read length needs to be longer than the paired-end cut-off value\n\n";
	}
      }
    }

    if ($retain){
      $length_read_1 = 35 unless (defined $length_read_1);
      $length_read_2 = 35 unless (defined $length_read_2);
    }
  }

  unless ($no_report_file){
    $no_report_file = 0;
  }

  ### OUTPUT DIR PATH
  if ($output_dir){
    unless ($output_dir =~ /\/$/){
      $output_dir =~ s/$/\//;
    }
  }
  else{
    $output_dir = '';
  }

  return ($quality,$adapter,$stringency,$rrbs,$length_cutoff,$keep,$fastqc,$non_directional,$phred_encoding,$fastqc_args,$trim,$gzip,$validate,$retain,$length_read_1,$length_read_2,$adapter2,$error_rate,$output_dir,$no_report_file);
}




sub print_helpfile{
  print << "HELP";

 USAGE:

trim_galore [options] <filename(s)>


-h/--help               Print this help message and exits.

-v/--version            Print the version information and exits.

-q/--quality <INT>      Trim low-quality ends from reads in addition to adapter removal. For
                        RRBS samples, quality trimming will be performed first, and adapter
                        trimming is carried in a second round. Other files are quality and adapter
                        trimmed in a single pass. The algorithm is the same as the one used by BWA
                        (Subtract INT from all qualities; compute partial sums from all indices
                        to the end of the sequence; cut sequence at the index at which the sum is
                        minimal). Default Phred score: 20.

--phred33               Instructs Cutadapt to use ASCII+33 quality scores as Phred scores
                        (Sanger/Illumina 1.9+ encoding) for quality trimming. Default: ON.

--phred64               Instructs Cutadapt to use ASCII+64 quality scores as Phred scores
                        (Illumina 1.5 encoding) for quality trimming.

--fastqc                Run FastQC in the default mode on the FastQ file once trimming is complete.

--fastqc_args "<ARGS>"  Passes extra arguments to FastQC. If more than one argument is to be passed
                        to FastQC they must be in the form "arg1 arg2 etc.". An example would be:
                        --fastqc_args "--nogroup --outdir /home/". Passing extra arguments will
                        automatically invoke FastQC, so --fastqc does not have to be specified
                        separately.

-a/--adapter <STRING>   Adapter sequence to be trimmed. If not specified explicitely, the first 13
                        bp of the Illumina adapter 'AGATCGGAAGAGC' will be used by default.

-a2/--adapter2 <STRING> Optional adapter sequence to be trimmed off read 2 of paired-end files. This
                        option requires '--paired' to be specified as well.


-s/--stringency <INT>   Overlap with adapter sequence required to trim a sequence. Defaults to a
                        very stringent setting of '1', i.e. even a single bp of overlapping sequence
                        will be trimmed of the 3' end of any read.

-e <ERROR RATE>         Maximum allowed error rate (no. of errors divided by the length of the matching
                        region) (default: 0.1)

--gzip                  Compress the output file with gzip. If the input files are gzip-compressed
                        the output files will be automatically gzip compressed as well.

--length <INT>          Discard reads that became shorter than length INT because of either
                        quality or adapter trimming. A value of '0' effectively disables
                        this behaviour. Default: 20 bp.

                        For paired-end files, both reads of a read-pair need to be longer than
                        <INT> bp to be printed out to validated paired-end files (see option --paired).
                        If only one read became too short there is the possibility of keeping such
                        unpaired single-end reads (see --retain_unpaired). Default pair-cutoff: 20 bp.

-o/--output_dir <DIR>   If specified all output will be written to this directory instead of the current
                        directory.

--no_report_file        If specified no report file will be generated.

--suppress_warn         If specified any output to STDOUT or STDERR will be suppressed.



RRBS-specific options (MspI digested material):

--rrbs                  Specifies that the input file was an MspI digested RRBS sample (recognition
                        site: CCGG). Sequences which were adapter-trimmed will have a further 2 bp
                        removed from their 3' end. This is to avoid that the filled-in C close to the
                        second MspI site in a sequence is used for methylation calls. Sequences which
                        were merely trimmed because of poor quality will not be shortened further.

--non_directional       Selecting this option for non-directional RRBS libraries will screen
                        quality-trimmed sequences for 'CAA' or 'CGA' at the start of the read
                        and, if found, removes the first two basepairs. Like with the option
                        '--rrbs' this avoids using cytosine positions that were filled-in
                        during the end-repair step. '--non_directional' requires '--rrbs' to
                        be specified as well.

--keep                  Keep the quality trimmed intermediate file. Default: off, which means
                        the temporary file is being deleted after adapter trimming. Only has
                        an effect for RRBS samples since other FastQ files are not trimmed
                        for poor qualities separately.


Note for RRBS using MseI:

If your DNA material was digested with MseI (recognition motif: TTAA) instead of MspI it is NOT necessary
to specify --rrbs or --non_directional since virtually all reads should start with the sequence
'TAA', and this holds true for both directional and non-directional libraries. As the end-repair of 'TAA'
restricted sites does not involve any cytosines it does not need to be treated especially. Instead, simply
run Trim Galore! in the standard (i.e. non-RRBS) mode.


Paired-end specific options:

--paired                This option performs length trimming of quality/adapter/RRBS trimmed reads for
                        paired-end files. To pass the validation test, both sequences of a sequence pair
                        are required to have a certain minimum length which is governed by the option
                        --length (see above). If only one read passes this length threshold the
                        other read can be rescued (see option --retain_unpaired). Using this option lets
                        you discard too short read pairs without disturbing the sequence-by-sequence order
                        of FastQ files which is required by many aligners.

                        Trim Galore! expects paired-end files to be supplied in a pairwise fashion, e.g.
                        file1_1.fq file1_2.fq SRR2_1.fq.gz SRR2_2.fq.gz ... .

-t/--trim1              Trims 1 bp off every read from its 3' end. This may be needed for FastQ files that
                        are to be aligned as paired-end data with Bowtie. This is because Bowtie (1) regards
                        alignments like this:

                          R1 --------------------------->     or this:    ----------------------->  R1
                          R2 <---------------------------                       <-----------------  R2

                        as invalid (whenever a start/end coordinate is contained within the other read).

--retain_unpaired       If only one of the two paired-end reads became too short, the longer
                        read will be written to either '.unpaired_1.fq' or '.unpaired_2.fq'
                        output files. The length cutoff for unpaired single-end reads is
                        governed by the parameters -r1/--length_1 and -r2/--length_2. Default: OFF.

-r1/--length_1 <INT>    Unpaired single-end read length cutoff needed for read 1 to be written to
                        '.unpaired_1.fq' output file. These reads may be mapped in single-end mode.
                        Default: 35 bp.

-r2/--length_2 <INT>    Unpaired single-end read length cutoff needed for read 2 to be written to
                        '.unpaired_2.fq' output file. These reads may be mapped in single-end mode.
                        Default: 35 bp.


Last modified on 18 Oct 2012.

HELP
  exit;
}
