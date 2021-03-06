args = commandArgs(trailingOnly = TRUE)

DEBUG=0
if(!DEBUG){
  readFileList<-args[1]
  resultPrefix<-args[2]
}else{
  readFileList="/scratch/cqs/shengq1/vickers/20161223_smallRNA_3018-KCV-77_78_79_86_v3/data_visualization/map_percentage/result/Urine_WT_14.filelist"
  resultPrefix="/scratch/cqs/shengq1/vickers/20161223_smallRNA_3018-KCV-77_78_79_86_v3/data_visualization/map_percentage/result/Urine_WT_14"
}

cat("readFileList=", readFileList, "\n")
cat("resultPrefix=", resultPrefix, "\n")

require(XML)
library(ggplot2)

curFiles<-read.delim(readFileList,header=F,as.is=T)
curFiles$Category<-"Nonhost"
curFiles$Category[2]<-"Host smallRNA"
curFiles$Category[3]<-"Host genome"
allReads<-read.table(curFiles[1,1], sep="\t", header=T, row.names=1)[,c("Count"),drop=F]
allReads$Mapped<-"Unmapped"
mapIndex<-3
for (mapIndex in c(2:nrow(curFiles))){
  mapFile<-curFiles[mapIndex,1]
  if(grepl(".xml", mapFile)){
    cat("Xml: ", mapFile, "\n")
    xml_data <- xmlToList(mapFile)
    temp<-xml_data[["queries"]]
    qnames<-sapply(temp,function(x) {
      xLength=length(x);
      x[[xLength]]["name"];
    })
    qnames<-gsub(":CLIP_.*", "", qnames )
  }else{
    cat("Txt: ", mapFile, "\n")
    qnames<-read.table(mapFile, sep="\t", header=T, stringsAsFactor=F)$Query
  }
  allReads[qnames,"Mapped"]<-curFiles[mapIndex,"Category"]
}

uniqueCounts<-unique(allReads$Count)
x<-1
res<-lapply(uniqueCounts, function(x){
  ta<-table(allReads$Mapped[allReads$Count==x])
  df<-data.frame(ta)
  df$Count=x
  return(df)
})
df<-do.call(rbind, res)
colnames(df)<-c("Category", "Value", "ReadCount")

write.csv(df, paste0(resultPrefix, ".csv"))

df<-df[df$ReadCount <=20,]
df$ReadCount<-factor(df$ReadCount)
df$Measure<-"Frequency"

df2<-df
temp<-tapply(df[,"Value"],df[,"ReadCount"],sum)
df2$Value<-df[,"Value"]/temp[df[,"ReadCount"]] * 100
df2$Measure<-"Percentage"

dfall<-rbind(df, df2)
dfall$Category=factor(dfall$Category, levels=c("Host smallRNA","Host genome","Nonhost","Unmapped"))
g<-ggplot(dfall, aes(x=ReadCount, y=Value, fill=Category)) + geom_bar(stat="identity") + facet_wrap(~Measure, nrow=2, scales="free_y")
png(file=paste0(resultPrefix, ".png"), width=1600, height=2000, res=300)
print(g)
dev.off()
