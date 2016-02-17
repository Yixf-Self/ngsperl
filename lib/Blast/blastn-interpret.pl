use strict;
use warnings;

my $output_file = $ARGV[0];
my $input_file  = $ARGV[1];

#$input_file = "../../data/3116_human_41_50.blastn.tsv";
#$output_file = "../../data/3116_human_41_50.blastn.table.tsv";

my %res;
foreach my $file ( split( ",", $input_file ) ) {
  open( my $input, "<$file" ) or die "Cannot open $file";
  while (<$input>) {
    chomp;
    my @parts  = split( "\t", $_ );
    my $seq    = $parts[0];
    my $genome = $parts[2];
    $genome =~ s/PREDICTED: //g;
    $genome =~ s/Homologies in //g;

    if ( $genome =~ /human/i || $genome =~ /homo sapiens/i ) {
      $genome = "Human";
    }
    elsif ( $genome =~ /rat/i || $genome =~ /rattus norvegicus/i ) {
      $genome = "Rat";
    }
    elsif ( $genome =~ /mouse/i || $genome =~ /Mus musculus/i ) {
      $genome = "Mouse";
    }
    else {
      my @tokens = split( " ", $genome );
      if ( scalar(@tokens) == 1 ) {
        if ( $tokens[0] ne "N/A" ) {
          $genome = $tokens[0];
        }
        else {
          next;
        }
      }
      else {
        if ( $tokens[1] =~ /^\d/ ) {
          $genome = $tokens[0];
        }
        else {
          $genome = $tokens[0] . " " . $tokens[1];
        }
      }
    }

    #print $seq, "\t", $genome, "\n";
    $res{$genome}{$seq} = 1;
  }
  close($input);
}

open( my $output, ">$output_file" ) or die "Cannot open $output_file";
printf $output "genome\tunique_sequence_count\tsequences\n";

foreach my $name (
  sort {
    my $counta = keys %{ $res{$a} };
    my $countb = keys %{ $res{$b} };
    $countb <=> $counta
  } keys %res
  )
{
  my $count = keys %{ $res{$name} };
  my $sequences = join( ";", keys %{ $res{$name} } );
  printf $output "%s\t%d\t%s\n", $name, $count, $sequences;
}
close($output);
