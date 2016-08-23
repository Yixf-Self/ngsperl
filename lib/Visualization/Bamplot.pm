#!/usr/bin/perl
package Visualization::Bamplot;

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use File::Copy;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::NGSCommon;
use CQS::GroupTask;
use CQS::StringUtils;

our @ISA = qw(CQS::GroupTask);

my $directory;

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = __PACKAGE__;
  $self->{_suffix} = "_bp";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $bam_files = get_raw_files( $config, $section );
  my $groups = get_raw_files( $config, $section, "groups" );
  my $singlepdf = get_option( $config, $section, "single_pdf", 0 ) ? "-s" : "";
  my $rainbow_color => get_option( $config, $section, "rainbow_color", 1 );

  my $gff_file = parse_param_file( $config, $section, "gff_file", 1 );

  my $shfile = $self->get_task_filename( $pbs_dir, $task_name );
  open( my $sh, ">$shfile" ) or die "Cannot create $shfile";
  print $sh get_run_command($sh_direct);

  for my $name ( sort keys %{$groups} ) {
    my $curgff = "${name}.gff";
    copy( $gff_file, "${result_dir}/${curgff}" );

    my @curbam_names = @{ $groups->{$name} };
    my @curbam_files = ();
    my @black_colors = ();
    for my $bamName (@curbam_names) {
      push( @curbam_files, $bam_files->{$bamName}->[0] );
      push( @black_colors, "0,0,0" );
    }

    my $curbam_nameStr = join( ',', @curbam_names );
    my $curbam_fileStr = join( ',', @curbam_files );
    my $colorStr = $rainbow_color ? "" : "--color " . join( ',', @black_colors );

    my $pbs_file = $self->get_pbs_filename( $pbs_dir, $name );
    my $pbs_name = basename($pbs_file);
    my $log      = $self->get_log_filename( $log_dir, $name );

    print $sh "\$MYCMD ./$pbs_name \n";
    my $log_desc = $cluster->get_log_description($log);

    my $final_file = $result_dir . "/${name}.pdf";

    my $pbs = $self->open_pbs( $pbs_file, $pbs_desc, $log_desc, $path_file, $result_dir, $final_file );
    print $pbs "bamplot $option -b $curbam_fileStr -n $curbam_nameStr -y uniform -i $curgff $colorStr -o . \n";
    $self->close_pbs( $pbs, $pbs_file );
  }

  close $sh;

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all " . $self->{_name} . " tasks.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct ) = get_parameter( $config, $section, 0 );

  my $groups = get_raw_files( $config, $section, "groups" );

  my $result = {};
  for my $name ( sort keys %{$groups} ) {
    my @result_files = ();
    push( @result_files, "${result_dir}/${name}_plots.pdf" );
    $result->{$name} = filter_array( \@result_files, $pattern );
  }
  return $result;
}

1;
