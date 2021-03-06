
library(ChIPpeakAnno)
genes <- toGRanges(parFile1, format="BED", skip=1)
files<-read.table(parSampleFile1, sep="\t", header=F)
for (file in files$V1){
  macsOutput <- toGRanges(file, format="BED", skip=1)
  annotated <- annotatePeakInBatch(macsOutput, AnnotationData=genes)
  
  df<-mcols(annotated)
  df$seqnames<-seqnames(annotated)
  df$peak_start<-start(annotated)
  df$peak_end<-end(annotated)
  
  df<-df[,c("seqnames", "peak_start", "peak_end", "peak", "score", "feature", "start_position", "end_position", "insideFeature", "distancetoFeature", "shortestDistance")]
  colnames(df)<-c("chr", "start", "end", "feature", "score", "gene", "gene_start", "gene_end", "insideGene", "distanceToGene", "shortestDistanceToGene")
  
  write.table(df, file=paste0(file, ".nearest_gene.txt"), quote=F, row.names=F, sep="\t")
}
