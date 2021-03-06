#!/usr/bin/perl
package Format::MergeFastq;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::Task;
use CQS::StringUtils;

our @ISA = qw(CQS::Task);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = __PACKAGE__;
  $self->{_suffix} = "_mf";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $ispaired = get_option( $config, $section, "is_paired" );
  my %raw_files = %{ get_raw_files( $config, $section ) };

  my $shfile = $self->get_task_filename( $pbs_dir, $task_name );
  open( my $sh, ">$shfile" ) or die "Cannot create $shfile";
  print $sh get_run_command($sh_direct) . "\n";

  for my $sample_name ( sort keys %raw_files ) {
    my @sample_files = @{ $raw_files{$sample_name} };

    my $pbs_file = $self->get_pbs_filename( $pbs_dir, $sample_name );
    my $pbs_name = basename($pbs_file);
    my $log      = $self->get_log_filename( $log_dir, $sample_name );

    print $sh "\$MYCMD ./$pbs_name \n";

    if ($ispaired) {
      my $final_1_fastq = $sample_name . ".1.fastq";
      my $final_1_file  = $sample_name . ".1.fastq.gz";
      my $final_2_fastq = $sample_name . ".2.fastq";
      my $final_2_file  = $sample_name . ".2.fastq.gz";
      my $log_desc      = $cluster->get_log_description($log);
      my $pbs           = $self->open_pbs( $pbs_file, $pbs_desc, $log_desc, $path_file, $result_dir, $final_1_file );

      my $file_count = scalar(@sample_files);
      die "file count $file_count is not even for sample $sample_name @sample_files " if $file_count % 2 != 0;

      if ( scalar(@sample_files) == 2 ) {
        print $pbs "ln -s $sample_files[0] $final_1_file \n";
        print $pbs "ln -s $sample_files[1] $final_2_file \n";

        #print $pbs "cp $sample_files[0] $final_file \n";
      }
      else {
        print $pbs "
if [ -s $final_1_fastq ]; then
  rm $final_1_fastq
fi

if [ -s $final_2_fastq ]; then
  rm $final_2_fastq
fi
";
        for ( my $sample_index = 0 ; $sample_index < $file_count ; $sample_index += 2 ) {
          print $pbs "
echo merging $sample_files[$sample_index] ...
zcat $sample_files[$sample_index] >> $final_1_fastq 
echo merging $sample_files[$sample_index+1] ...
zcat $sample_files[$sample_index+1] >> $final_2_fastq 
";
        }
        print $pbs "
echo gzipping $final_1_fastq ...
gzip $final_1_fastq 
echo gzipping $final_2_fastq ...
gzip $final_2_fastq 
";
      }
      $self->close_pbs( $pbs, $pbs_file );

    }
    else {
      my $final_fastq = $sample_name . ".fastq";
      my $final_file  = $sample_name . ".fastq.gz";
      my $log_desc    = $cluster->get_log_description($log);
      my $pbs         = $self->open_pbs( $pbs_file, $pbs_desc, $log_desc, $path_file, $result_dir, $final_file );

      if ( scalar(@sample_files) == 1 ) {
        print $pbs "ln -s $sample_files[0] $final_file \n";

        #print $pbs "cp $sample_files[0] $final_file \n";
      }
      else {
        print $pbs "if [ -s $final_fastq ]; then
  rm $final_fastq
fi
";
        for my $sample_file (@sample_files) {
          print $pbs "
echo merging $sample_file ...
zcat $sample_file >> $final_fastq 
";
        }
        print $pbs "
echo gzipping $final_fastq ...
gzip $final_fastq \n";
      }
      $self->close_pbs( $pbs, $pbs_file );
    }
  }
  close $sh;

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all Bam2Fastq tasks.\n";

  #`qsub $pbs_file`;
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct ) = get_parameter( $config, $section, 0 );

  my $ispaired = get_option( $config, $section, "is_paired");

  my %raw_files = %{ get_raw_files( $config, $section ) };

  my $result = {};
  for my $sample_name ( keys %raw_files ) {
    my @result_files = ();
    if ($ispaired) {
      my $final_1_file  = $sample_name . ".1.fastq.gz";
      my $final_2_file  = $sample_name . ".2.fastq.gz";
      push( @result_files, $result_dir . "/" . $final_1_file );
      push( @result_files, $result_dir . "/" . $final_2_file );
    }
    else {
      my $final_file = $sample_name . ".fastq.gz";
      push( @result_files, $result_dir . "/" . $final_file );
    }
    $result->{$sample_name} = filter_array( \@result_files, $pattern );

  }
  return $result;
}

1;
