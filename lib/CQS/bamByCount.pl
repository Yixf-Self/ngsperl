use strict;
use warnings;

my $outFile=$ARGV[0];
my $targetChr=$ARGV[1]; #"NC_012660.1"
my $bamFile=$ARGV[2];
my $dupCountFile=$ARGV[3];
#my $bamFile="/scratch/cqs/zhaos/vickers/20160503_smallRNA_3018-KCV_68_human/nonhost_genome/bowtie1_bacteria_group2_pm/result/Control_25/Control_25.bam";
#my $dupCountFile="/scratch/cqs/zhaos/vickers/20160503_smallRNA_3018-KCV_68_human/preprocessing/identical/result/Control_25_clipped_identical.fastq.dupcount";

#my $outFile="/scratch/cqs/zhaos/temp/temp1";

open (DUPCOUNT, $dupCountFile) or die $!;
my %read2Count;
while(<DUPCOUNT>) {
    my @lines=( split '\t', $_ );
    $read2Count{$lines[0]}=$lines[1];
}

open( BAMHEAD, "samtools view -H $bamFile|" ) or die $!;
open( OUT, ">${outFile}.sam" ) or die $!;

while (<BAMHEAD>) {
	print OUT $_;
}
close(BAMHEAD);

my $readNumber=0;
my $uniqueReadNumber=0;
open( BAMLINE, "samtools view $bamFile|" ) or die $!;
while (<BAMLINE>) {
	my @lines=( split '\t', $_ );
	my $readId=$lines[0];
	my $chr=$lines[2];
	if ($chr eq $targetChr) {
		$uniqueReadNumber++;
		foreach my $i (1..$read2Count{$readId}) {
			$lines[0]=$readId.".".$i;
			my $newLine=join("\t",@lines);
			print OUT $newLine;
			$readNumber++;
		}
	}
}
close(BAMLINE);
close(OUT);

`samtools view -bS -o ${outFile}.bam ${outFile}.sam`;
`samtools index ${outFile}.bam`;
`rm ${outFile}.sam`;

print "$uniqueReadNumber unique reads ($readNumber reads) were selected and saved into ${outFile}.bam.\n";
