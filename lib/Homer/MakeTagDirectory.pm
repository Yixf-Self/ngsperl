#!/usr/bin/perl
package Homer::MakeTagDirectory;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::Task;
use CQS::NGSCommon;
use CQS::StringUtils;

our @ISA = qw(CQS::Task);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = "Homer::MakeTagDirectory";
  $self->{_suffix} = "_mtd";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my %bamFiles = %{ get_raw_files( $config, $section ) };

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct);

  my $threadcount = get_pbs_thread( $config->{$section}{pbs} );

  for my $sampleName ( sort keys %bamFiles ) {
    my @sampleFiles = @{ $bamFiles{$sampleName} };
    my $samples = join( " ", @sampleFiles );

    my $pbsFile = $self->pbsfile( $pbsDir, $sampleName );
    my $pbsName = basename($pbsFile);
    my $log     = $self->logfile( $logDir, $sampleName );

    my $curDir      = create_directory_or_die( $resultDir . "/$sampleName" );

    open( OUT, ">$pbsFile" ) or die $!;

    print OUT "$pbsDesc
#PBS -o $log
#PBS -j oe

$path_file

cd $curDir 

echo homer_MakeTagDirectory_start=`date` 

makeTagDirectory $curDir $samples

echo homer_MakeTagDirectory_finished=`date` 

";
    close(OUT);

    print SH "\$MYCMD ./$pbsName \n";
    print "$pbsFile created\n";
  }
  print SH "exit 0\n";
  close(SH);

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all tasks.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my %rawFiles = %{ get_raw_files( $config, $section ) };

  my $result = {};
  for my $sampleName ( keys %rawFiles ) {
    my @resultFiles = ();
    push( @resultFiles, "${resultDir}/${sampleName}" );
    $result->{$sampleName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
