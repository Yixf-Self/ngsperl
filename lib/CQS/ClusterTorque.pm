#!/usr/bin/perl
package CQS::ClusterTorque;

use strict;
use warnings;
use CQS::ClusterScript;

our @ISA = qw(CQS::ClusterScript);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name} = "ClusterTorque";
  bless $self, $class;
  return $self;
}

sub get_cluster_desc {
  my $walltime = "48";
  my $email    = "";
  my $mem      = "15000mb";
  my $nodes    = "1";

  my ($pbsParamHashRef) = @_;
  if ( defined $pbsParamHashRef ) {
    my %hash = %{$pbsParamHashRef};
    foreach ( keys %hash ) {
      if ( $_ eq "walltime" ) {
        $walltime = $hash{$_};
      }
      elsif ( $_ eq "email" ) {
        $email = $hash{$_};
      }
      elsif ( $_ eq "mem" ) {
        $mem = $hash{$_};
      }
      elsif ( $_ eq "nodes" ) {
        $nodes = $hash{$_};
      }
    }
  }

  die "Assign email address in hash (\"email\" => \"youremail\") and pass hash as parameter to get_cluster_desc" if ( $email eq "" );

  my $pbsDesc = <<PBS;
#!/bin/bash
#Beginning of PBS bash script
#PBS -M $email
#Status/Progress Emails to be sent
#PBS -m bae
#Email generated at b)eginning, a)bort, and e)nd of jobs
#PBS -l nodes=$nodes
#Processors needed
#PBS -l mem=$mem
#Total job memory required (specify how many megabytes)
#PBS -l walltime=${walltime}:00:00
#You must specify Wall Clock time (hh:mm:ss) [Maximum allowed 30 days = 720:00:00]
#PBS -q all
PBS

  return ($pbsDesc);
}

sub get_log_desc {
  my ($pbsfile) = @_;
  
  my $result = <<PBS;
#PBS -o $pbsfile
#PBS -j oe
PBS
  
  return ($result);
}

sub get_submit_command {
  return ("qsub");
}

1;
