#!/usr/bin/perl
package Pipeline::SmallRNAUtils;

use strict;
use warnings;
use CQS::FileUtils;
use CQS::SystemUtils;
use CQS::ConfigUtils;
use CQS::ClassFactory;
use Data::Dumper;
use Hash::Merge qw( merge );

require Exporter;
our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [qw(getSmallRNADefinition getPrepareConfig saveConfig)] );

our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

our $VERSION = '0.01';

#an example of parameter userdef
#my $userdef = {
#
#  #General options
#  task_name  => "parclip_NIH",
#  email      => "quanhu.sheng\@vanderbilt.edu",
#  target_dir => "/scratch/cqs/shengq1/vickers/20150925_parclip_3018-KCV-15/",
#  max_thread => 8,
#  cluster    => "slurm",
#
#  #Default software parameter (don't change it except you really know it)
#  fastq_remove_N => 0,
#  adapter        => "TGGAATTCTCGGGTGCCAAGG",
#
#  cqstools   => "/home/shengq1/cqstools/CQS.Tools.exe",
#
#  #Data
#  files => {
#    "3018-KCV-15-15" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-15_ATGTCA_L006_R1_001.fastq.gz"],
#    "3018-KCV-15-36" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-36_CCAACA_L006_R1_001.fastq.gz"],
#    "3018-KCV-15-37" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-37_CGGAAT_L006_R1_001.fastq.gz"],
#    "3018-KCV-15-46" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-46_TCCCGA_L006_R1_001.fastq.gz"],
#    "3018-KCV-15-47" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-47_TCGAAG_L006_R1_001.fastq.gz"],
#  },
#};
#
#an example of paramter $genome
#my $genome = {
#  #genome database
#  mirbase_count_option  => "-p hsa",
#  coordinate            => "/scratch/cqs/shengq1/references/smallrna/hg19_miRBase20_ucsc-tRNA_ensembl75.bed",
#  coordinate_fasta      => "/scratch/cqs/shengq1/references/smallrna/hg19_miRBase20_ucsc-tRNA_ensembl75.bed.fa",
#  bowtie1_index         => "/scratch/cqs/shengq1/references/hg19_16569_MT/bowtie_index_1.1.2/hg19_16569_MT",
#  bowtie1_miRBase_index => "/data/cqs/shengq1/reference/miRBase20/bowtie_index_1.1.1/mature.dna",
#  gsnap_index_directory => "/scratch/cqs/shengq1/references/hg19_16569_MT/gsnap_index_k14_2015-06-23/",
#  gsnap_index_name      => "hg19_16569_MT",
#  star_index_directory => "/scratch/cqs/shengq1/references/hg19_16569_MT/STAR_index_v37.75_2.4.2a_sjdb49"
#};

sub getSmallRNADefinition {
	my ( $userdef, $genome ) = @_;
	my $def = merge( $userdef, $genome );

	if ( !defined $def->{cluster} ) {
		$def->{cluster} = 'slurm';
	}

	if ( !defined $def->{min_read_length} ) {
		$def->{min_read_length} = 16;
	}

	if ( !defined $def->{smallrnacount_option} ) {
		$def->{smallrnacount_option} = '-s';
	}

	if ( !defined $def->{bowtie1_option_1mm} ) {
		$def->{bowtie1_option_1mm} = '-a -m 100 --best --strata -v 1 -p 8';
	}

	if ( !defined $def->{bowtie1_option_pm} ) {
		$def->{bowtie1_option_pm} = '-a -m 100 --best --strata -v 0 -p 8';
	}

	return $def;
}

sub getPrepareConfig {
	my ( $def, $hasNTA ) = @_;

	#print Dumper($def);

	create_directory_or_die( $def->{target_dir} );

	my $cluster = $def->{cluster};
	if ( !defined $cluster ) {
		$cluster = "slurm";
	}

	my $fastq_remove_N   = $def->{fastq_remove_N};
	my $run_cutadapt     = $def->{run_cutadapt};
	my $remove_sequences = $def->{remove_sequences};

	my $config = {
		general => {
			task_name => $def->{task_name},
			cluster   => $cluster
		},
		files => $def->{files}
	};

	if ( defined $def->{groups} ) {
		$config->{groups} = $def->{groups};
	}

	if ( defined $def->{pairs} ) {
		$config->{pairs} = $def->{pairs};
	}

	my @individual = ();
	my @summary    = ();

	my $source_ref = "files";
	my $len_ref    = "files";
	if ( !defined $fastq_remove_N || $fastq_remove_N ) {
		$config->{fastq_remove_N} = {
			class      => "CQS::FastqTrimmer",
			perform    => $fastq_remove_N,
			target_dir => $def->{target_dir} . "/fastq_remove_N",
			option     => "-n -z",
			extension  => "_trim.fastq.gz",
			source_ref => "files",
			cqstools   => $def->{cqstools},
			cluster    => $cluster,
			sh_direct  => 1,
			pbs        => {
				"email"    => $def->{email},
				"nodes"    => "1:ppn=1",
				"walltime" => "2",
				"mem"      => "10gb"
			}
		};
		$source_ref = "fastq_remove_N";
		$len_ref    = "fastq_remove_N";
		push @individual, "fastq_remove_N";
	}

	my $qc = {};
	if ( !defined $run_cutadapt || $run_cutadapt ) {
		my $adapter = $def->{adapter};
		if ( !defined $adapter ) {
			$adapter = "TGGAATTCTCGGGTGCCAAGG";
		}

		$qc = {
			fastqc_pre_trim => {
				class      => "QC::FastQC",
				perform    => 1,
				target_dir => $def->{target_dir} . "/fastqc_pre_trim",
				option     => "",
				source_ref => $source_ref,
				cluster    => $cluster,
				pbs        => {
					"email"    => $def->{email},
					"nodes"    => "1:ppn=1",
					"walltime" => "2",
					"mem"      => "10gb"
				},
			},
			fastqc_pre_trim_summary => {
				class      => "QC::FastQCSummary",
				perform    => 1,
				target_dir => $def->{target_dir} . "/fastqc_pre_trim",
				cqstools   => $def->{cqstools},
				option     => "",
				cluster    => $cluster,
				pbs        => {
					"email"    => $def->{email},
					"nodes"    => "1:ppn=1",
					"walltime" => "2",
					"mem"      => "10gb"
				},
			},
			cutadapt => {
				class      => "Cutadapt",
				perform    => 1,
				target_dir => $def->{target_dir} . "/cutadapt",
				option     => "-O 10 -m " . $def->{min_read_length},
				source_ref => $source_ref,
				adapter    => $adapter,
				extension  => "_clipped.fastq",
				sh_direct  => 1,
				cluster    => $cluster,
				pbs        => {
					"email"    => $def->{email},
					"nodes"    => "1:ppn=1",
					"walltime" => "24",
					"mem"      => "20gb"
				},
			},
			fastqc_post_trim => {
				class      => "QC::FastQC",
				perform    => 1,
				target_dir => $def->{target_dir} . "/fastqc_post_trim",
				option     => "",
				source_ref => [ "cutadapt", ".fastq.gz" ],
				cluster    => $cluster,
				pbs        => {
					"email"    => $def->{email},
					"nodes"    => "1:ppn=1",
					"walltime" => "2",
					"mem"      => "10gb"
				},
			},
			fastqc_post_trim_summary => {
				class      => "QC::FastQCSummary",
				perform    => 1,
				target_dir => $def->{target_dir} . "/fastqc_post_trim",
				cqstools   => $def->{cqstools},
				option     => "",
				cluster    => $cluster,
				pbs        => {
					"email"    => $def->{email},
					"nodes"    => "1:ppn=1",
					"walltime" => "2",
					"mem"      => "10gb"
				},
			}
		};
		$source_ref = [ "cutadapt", ".fastq.gz" ];
		$len_ref = "cutadapt";
		push @individual, ( "fastqc_pre_trim", "cutadapt", "fastqc_post_trim" );
		push @summary, ( "fastqc_pre_trim_summary", "fastqc_post_trim_summary" );
	}
	else {
		$qc = {
			fastqc => {
				class      => "QC::FastQC",
				perform    => 1,
				target_dir => $def->{target_dir} . "/fastqc",
				option     => "",
				source_ref => $source_ref,
				cluster    => $cluster,
				pbs        => {
					"email"    => $def->{email},
					"nodes"    => "1:ppn=1",
					"walltime" => "2",
					"mem"      => "10gb"
				},
			},
			fastqc_summary => {
				class      => "QC::FastQCSummary",
				perform    => 1,
				target_dir => $def->{target_dir} . "/fastqc",
				cqstools   => $def->{cqstools},
				option     => "",
				cluster    => $cluster,
				pbs        => {
					"email"    => $def->{email},
					"nodes"    => "1:ppn=1",
					"walltime" => "2",
					"mem"      => "10gb"
				},
			}
		};
		push @individual, ("fastqc");
		push @summary,    ("fastqc_summary");
	}

	$config = merge( $config, $qc );

	#print Dumper($config);
	$config->{"fastq_len"} = {
		class      => "FastqLen",
		perform    => 1,
		target_dir => $def->{target_dir} . "/fastq_len",
		option     => "",
		source_ref => $len_ref,
		cqstools   => $def->{cqstools},
		sh_direct  => 1,
		cluster    => $cluster,
		pbs        => {
			"email"    => $def->{email},
			"nodes"    => "1:ppn=1",
			"walltime" => "24",
			"mem"      => "20gb"
		},
	};
	push @individual, ("fastq_len");

	if ( defined $remove_sequences ) {
		$config->{"remove_sequences"} = {
			class      => "CQS::Perl",
			perform    => 1,
			target_dir => $def->{target_dir} . "/remove_sequences",
			option     => "$remove_sequences",
			output_ext => "_clipped_removeSeq.fastq.gz",
			perlFile   => "removeSequenceInFastq.pl",
			source_ref => $source_ref,
			sh_direct  => 1,
			cluster    => $cluster,
			pbs        => {
				"email"    => $def->{email},
				"nodes"    => "1:ppn=1",
				"walltime" => "24",
				"mem"      => "20gb"
			},
		};
		push @individual, ("remove_sequences");
		$source_ref = [ "remove_sequences", ".fastq.gz" ];

		$config->{"fastqc_post_remove"} = {
			class      => "QC::FastQC",
			perform    => 1,
			target_dir => $def->{target_dir} . "/fastqc_post_remove",
			option     => "",
			source_ref => $source_ref,
			cluster    => $cluster,
			pbs        => {
				"email"    => $def->{email},
				"nodes"    => "1:ppn=1",
				"walltime" => "2",
				"mem"      => "10gb"
			},
		};
		$config->{"fastqc_post_remove_summary"} = {
			class      => "QC::FastQCSummary",
			perform    => 1,
			target_dir => $def->{target_dir} . "/fastqc_post_remove",
			cqstools   => $def->{cqstools},
			option     => "",
			cluster    => $cluster,
			pbs        => {
				"email"    => $def->{email},
				"nodes"    => "1:ppn=1",
				"walltime" => "2",
				"mem"      => "10gb"
			},
		};
		push @individual, ("fastqc_post_remove");
		push @summary,    ("fastqc_post_remove_summary");

		if ( !defined $run_cutadapt || $run_cutadapt ) {
			$config->{"fastqc_count_vis"} = {
				class              => "CQS::UniqueR",
				perform            => 1,
				target_dir         => $def->{target_dir} . "/fastqc_post_remove",
				rtemplate          => "countInFastQcVis.R",
				output_file        => ".countInFastQcVis.Result",
				parameterFile1_ref => [ "fastqc_pre_trim_summary", ".FastQC.reads.tsv\$" ],
				parameterFile2_ref => [ "fastqc_post_trim_summary", ".FastQC.reads.tsv\$" ],
				parameterFile3_ref => [ "fastqc_post_remove_summary", ".FastQC.reads.tsv\$" ],
				sh_direct          => 1,
				pbs                => {
					"email"    => $def->{email},
					"nodes"    => "1:ppn=1",
					"walltime" => "1",
					"mem"      => "10gb"
				},
			  };
        push @summary,    ("fastqc_count_vis");
		}
	}

	my $preparation = {
		identical => {
			class      => "FastqIdentical",
			perform    => 1,
			target_dir => $def->{target_dir} . "/identical",
			option     => "",
			source_ref => $source_ref,
			cqstools   => $def->{cqstools},
			extension  => "_clipped_identical.fastq.gz",
			sh_direct  => 1,
			cluster    => $cluster,
			pbs        => {
				"email"    => $def->{email},
				"nodes"    => "1:ppn=1",
				"walltime" => "24",
				"mem"      => "20gb"
			},
		},
		identical_sequence_count_table => {
			class      => "CQS::SmallRNASequenceCountTable",
			perform    => 1,
			target_dir => $def->{target_dir} . "/identical_sequence_count_table",
			option     => "",
			source_ref => [ "identical", ".dupcount\$" ],
			cqs_tools  => $def->{cqstools},
			suffix     => "_sequence",
			sh_direct  => 1,
			cluster    => $cluster,
			pbs        => {
				"email"    => $def->{email},
				"nodes"    => "1:ppn=1",
				"walltime" => "10",
				"mem"      => "10gb"
			},
		},
	};

	push @individual, ("identical");
	push @summary,    ("identical_sequence_count_table");

	if ( !defined $hasNTA || $hasNTA ) {
		$preparation->{identical_NTA} = {
			class        => "CQS::FastqMirna",
			perform      => 1,
			target_dir   => $def->{target_dir} . "/identical_NTA",
			option       => "-l " . $def->{min_read_length},
			source_ref   => [ "identical", ".fastq.gz\$" ],
			seqcount_ref => [ "identical", ".dupcount\$" ],
			cqstools     => $def->{cqstools},
			extension    => "_clipped_identical_NTA.fastq.gz",
			sh_direct    => 1,
			cluster      => $cluster,
			pbs          => {
				"email"    => $def->{email},
				"nodes"    => "1:ppn=1",
				"walltime" => "24",
				"mem"      => "20gb"
			},
		};
		push @individual, ("identical_NTA");
	}

	$config = merge( $config, $preparation );

	return ( $config, \@individual, \@summary, $cluster, $source_ref );
}

sub saveConfig {
	my ( $def, $config ) = @_;

	my $defFile;
	if ( $def->{target_dir} =~ /\/$/ ) {
		$defFile = $def->{target_dir} . $def->{task_name} . '.def';
	}
	else {
		$defFile = $def->{target_dir} . '/' . $def->{task_name} . '.def';
	}

	open( SH, ">$defFile" ) or die "Cannot create $defFile";
	print SH Dumper($def);
	close(SH);
	print "Saved user definition file to " . $defFile . "\n";

	my $configFile;
	if ( $def->{target_dir} =~ /\/$/ ) {
		$configFile = $def->{target_dir} . $def->{task_name} . '.config';
	}
	else {
		$configFile = $def->{target_dir} . '/' . $def->{task_name} . '.config';
	}

	open( SH, ">$configFile" ) or die "Cannot create $configFile";
	print SH Dumper($config);
	close(SH);
	print "Saved configuration file to " . $configFile . "\n";
}

1;
