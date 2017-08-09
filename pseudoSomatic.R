library(tidyverse)
library(magrittr)

args=commandArgs(trailing=T)


maf=read_tsv(args[1])
normal=args[2]
tumor=args[3]

maf %<>% mutate(UUID=paste0(CHROM,":",POS,":",REF,":",ALT))

smaf=maf %>%
    mutate(SAMP=ifelse(SAMPLE==normal,"NORM","TUM")) %>%
    select(GENE,SAMP,CHROM,POS,REF,ALT,GT,AD_REF,AD_ALT,matches("SNP")) %>%
    gather(key,val,GT,AD_REF,AD_ALT) %>%
    unite(key2,SAMP,key,sep=".") %>%
    spread(key2,val) %>%
    filter(NORM.GT=="0/0" & TUM.GT=="1/1")


maf %>%
    select(2,4,5,6,10,13:14) %>%
    gather(key,val,5:7) %>%
    unite(key2,SAMPLE,key,sep=".") %>%
    spread(key2,val) %>%
    filter(s_2_E486.GT=="0/0" & s_1_ER11.GT=="1/1")

omaf = smaf %>%
    select(-matches("_SNP"),matches("_SNP")) %>%
    mutate(SAMPLE=tumor,NORMAL=normal) %>% select((ncol(.)-1):ncol(.),1:(ncol(.)-2))

omaf %<>% mutate_each(funs(parse_guess))

options( java.parameters = c("-Xss2560k", "-Xmx8g") )
library(xlsx)

write.xlsx(as.data.frame(omaf),gsub(".maf","__SOMATIC.xlsx",args[1]),row.names=F)