##Uses scoring function without splice acceptor and donor as C4
.libPaths(c( "/home/shu/R/x86_64-redhat-linux-gnu-library/3.4", .libPaths() ) )

##Aug6 remove VAF NaN's(multiallelic split issue; error in code for HAIL computation)
##Aug7 remove NMD variants
##Rcommendation for SKAT; use a hard filter of comb_score > 5 compared to comb_score >= 5
##Aug12 changed scoring function, increased penalty for last exon variants (-25)
##same as DT_call_analysis.R (refer it for source file details)
##Add filter using VAF > 0.3
##Use scores for C5 = C4 > C3 = Eigen
##weights assigned: C5 -> 45; C4 -> 45; C3 -> Eigen; last 5% protein sequence: score/2
##Scoring function: C5 := Clinvar Pathogenic; C4 := c("frameshift_variant", "start_lost", "stop_gained") 



Ex_tab <- read.delim("~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/test/Rep_set_variants/Rep_set_2044.tsv", sep = "\t",
                                          header = T, stringsAsFactors = F)
Ex_tab <- Ex_tab[!is.na(Ex_tab$SAMPLE),]
Ex_tab$SAMPLE <- gsub(".variant.*$", "", Ex_tab$SAMPLE) ##check this in the next run
#remove variants ending with Asterisk; these donot have vep annotation
Ex_tab <- Ex_tab[!is.na(Ex_tab$gene_symbol),]

Ex_tab <- Ex_tab[!is.na(Ex_tab$DP),] ##There are records with NA in DP attribute ; file: sept05_rect

#Ex_tab <- Ex_tab[is.na(Ex_tab$VAF),] ##VAF's have NaNs as DP = 0. Its a division by zero for VAF

#Ex_tab <- Ex_tab[!is.na(Ex_tab$VAF),]
#Ex_tab <- Ex_tab[Ex_tab$DP != 0,]
#table(Ex_tab[Ex_tab$VAF == "NaN",]$gene_symbol %in% c("TP53", "TINF2", "POT1", "SMARCAL1"))
Ex_tab <- Ex_tab[!(Ex_tab$VAF %in% "NaN"),]
class(Ex_tab$VAF) <- "numeric" ##remove headers from shards in the next run
Ex_tab <- Ex_tab[!is.na(Ex_tab$VAF),] ##some VAFs are NAs in sept05_rect file
##remove QC2 failed samples: 55 MGRB, 6 RISC, 7 LIONS, 18 ISKS
QC2_dat <- read.table("~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/test/Rep_set_variants/joint_calls_2019jan_2019nov.final_qc_output.tsv", header = T, sep = "\t", stringsAsFactors = F)
QC2_dat_fail <- QC2_dat[QC2_dat$passes_qc2 %in% "FALSE",]$new_sampleid

##CHIP filter
MGRB3_chip <- read.table("~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/test/Rep_set_variants/MGRB3_chip1.all_categories_nb2_depth_and_vaf_and_position_tallies.tsv", header = T, sep = "\t", stringsAsFactors = F)

#DT_gene_tab_ISKS_MGRB_nCH <-DT_gene_tab[DT_gene_tab$cohort %in% c("ISKS", "MGRB no CH"),]

#MGRB_noCH <- unique(DT_gene_tab[(DT_gene_tab$cohort) %in% "MGRB no CH",]$SAMPLE)

#MGRB_all <- unique(DT_gene_tab[(DT_gene_tab$cohort) %in% c("MGRB no CH", "MGRB"),]$SAMPLE)

t1 <- MGRB3_chip[match(Ex_tab$SAMPLE, MGRB3_chip$sample_id),4]
t2 <- ifelse(grepl("^CN", t1), 1, 0)
# t3 <- Ex_tab$SAMPLE
# t4 <- cbind.data.frame("is_CH" = t2, "SAMPLE" = t3)
# t5 <- Ex_tab[Ex_tab$is_CH == 1,]
# vec <- ifelse(!is.na(as.numeric(as.character(t5$SAMPLE))) | grepl("^CR|^LK",as.character(t5$SAMPLE)), 1, 0)
##113 MGRB samples with CHIP
Ex_tab$is_CH <- t2
##remove CHIP cases
Ex_tab1 <- Ex_tab[Ex_tab$is_CH == 0,]

#Ex_tab1 <- Ex_tab[Ex_tab$VAF >= 0.25 & Ex_tab$VAF < 1,] ##OR use the command below to not lose highly significant homozygous variants
Ex_tab1 <- Ex_tab1[as.numeric(Ex_tab1$VAF) >= 0.25 & as.numeric(Ex_tab1$DP) >= 10,] ##Depth filter
Ex_tab1$gnomad_AF_NFE <- gsub("\\[", "", Ex_tab1$gnomad_AF_NFE)
Ex_tab1$gnomad_AF_NFE <- gsub("\\]", "", Ex_tab1$gnomad_AF_NFE)
class(Ex_tab1$gnomad_AF_NFE) <- "numeric"
Ex_tab1$gnomad_AF_NFE <- ifelse(is.na(Ex_tab1$gnomad_AF_NFE), 0, Ex_tab1$gnomad_AF_NFE)

#Ex_tab_filt1 <- Ex_tab1[Ex_tab1$gnomad_AF_NFE <= 0.0001, ] ##check this; loses some variants from Aug12 on Sept05 run(don't use)

##remove SAMPLE CR57
Ex_tab_filt1 <- Ex_tab1[!(Ex_tab1$SAMPLE %in% "CR57"),]

toMatch <- c("3_prime_UTR_variant", "5_prime_UTR_variant", "intron_variant", 
             "synonymous_variant", "upstream_gene_variant", "non_coding_transcript_exon_variant",
             "non_coding_transcript_variant", "downstream_gene_variant", "NMD_transcript_variant",
             "intergenic_variant", "mature_miRNA_variant")
#"NMD_transcript_variant"
#Ex_tab_filt2 <- Ex_tab_filt1[!(Ex_tab_filt1$vep_consequence %in% toMatch),]
Ex_tab_filt2 <- Ex_tab_filt1[!(grepl(paste(toMatch,collapse="|"), 
                                    Ex_tab_filt1$vep_consequence)),]

##load ASPREE cancer cases and filter them out
load("~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/ASPREE_can.RData")

#Ex_tab_filt2$is_MGRB <- ifelse(!is.na(as.numeric(as.character(Ex_tab_filt2$SAMPLE))) | grepl("^CR|^LK",as.character(Ex_tab_filt2$SAMPLE)), 1, 0)

Ex_tab_filt2$is_ASPC <- ifelse(Ex_tab_filt2$SAMPLE %in% ASPREE_can$samp, 1, 0)

Ex_tab_noCH_filt3 <- Ex_tab_filt2[Ex_tab_filt2$is_ASPC == 0,]


##Capture variant present in the last 5% of the length of the protein sequence

Ex_tab_noCH_filt3$vep_Protein_position <- ifelse(is.na(Ex_tab_noCH_filt3$vep_Protein_position), 0, Ex_tab_noCH_filt3$vep_Protein_position)
class(Ex_tab_noCH_filt3$vep_Protein_position) <- "numeric"
Ex_tab_noCH_filt3$vep_Protein_position <- ifelse(is.na(Ex_tab_noCH_filt3$vep_Protein_position), 0, Ex_tab_noCH_filt3$vep_Protein_position)

#vep_hgvsp <- as.numeric(unlist(regmatches(vep_hgvsp, gregexpr("[[:digit:]]+", vep_hgvsp))))
#vep_hgvsp <- as.numeric(gsub("[^\\d]", "", vep_hgvsp, perl=TRUE))
#vep_hgvsp1 <- regmatches(vep_hgvsp, gregexpr("[[:digit:]]+", vep_hgvsp))
#vep_hgvsp2 <- as.numeric(unlist(lapply(vep_hgvsp1, function(x)x[1])))
#vep_comb_pos <- ifelse(vep_hgvsp2 == 0, Ex_tab_noCH_filt3$vep_Protein_position, vep_hgvsp2) #works but takes long

vep_hgvsp <- ifelse(is.na(Ex_tab_noCH_filt3$vep_hgvsp), 0, Ex_tab_noCH_filt3$vep_hgvsp)
vep_hgvsp <- gsub("^*.*p\\.","", vep_hgvsp)
vep_hgvsp <- gsub("Ter*.*$","", vep_hgvsp)
library(tidyr)
vep_hgvsp <- extract_numeric(vep_hgvsp)
#combine position from vep_Protein_position and vep_hgvsp
vep_comb_pos <- ifelse(vep_hgvsp == 0, Ex_tab_noCH_filt3$vep_Protein_position, vep_hgvsp)
Ex_tab_noCH_filt3$vep_comb_pos <- vep_comb_pos

dim(Ex_tab_noCH_filt3[Ex_tab_noCH_filt3$vep_consequence %in% "frameshift_variant",])
#check redundant records
#dim(Ex_tab_noCH_filt3[Ex_tab_noCH_filt3$vep_consequence %in% "frameshift_variant" & Ex_tab_noCH_filt3$vep_comb_pos == 0,])
#Ex_tab_noCH_filt3 <- Ex_tab_noCH_filt3[!is.na(Ex_tab_noCH_filt3$SAMPLE),]
Ex_tab_noCH_filt3$vep_comb_pos <- ifelse(is.na(Ex_tab_noCH_filt3$vep_comb_pos), 0, Ex_tab_noCH_filt3$vep_comb_pos)
##remove RNA genes
Ex_tab_noCH_filt3 <- Ex_tab_noCH_filt3[which(!is.na(as.numeric(Ex_tab_noCH_filt3$LONGEST_GENE_LENGTH_IN_AMINO_ACIDS))),]

Ex_tab_noCH_filt3 <- Ex_tab_noCH_filt3[Ex_tab_noCH_filt3$LONGEST_GENE_LENGTH_IN_AMINO_ACIDS != 0 
                                       & Ex_tab_noCH_filt3$CANONICAL_GENE_LENGTH_IN_AMIMO_ACIDS != 0,]
Ex_tab_noCH_filt3$last_five_perc <- ifelse((as.numeric(Ex_tab_noCH_filt3$LONGEST_GENE_LENGTH_IN_AMINO_ACIDS) - Ex_tab_noCH_filt3$vep_comb_pos)/
                                              (as.numeric(Ex_tab_noCH_filt3$LONGEST_GENE_LENGTH_IN_AMINO_ACIDS)) <= 0.05, 1,
                                           0)

##David algorithm JUl-22-2019
toMatch1 <- c("Likely_pathogenic", "Pathogenic", "Pathogenic/Likely_pathogenic", 
              "Pathogenic/Likely_pathogenic/drug_response", "Pathogenic/Likely_pathogenic/other",
              "Pathogenic/Affects", "Pathogenic/risk_factor", "Pathogenic/Likely_pathogenic/risk_factor")


##modify scoring function since the annotation from the new VEP are slightly different
toMatch2 <- c("frameshift_variant", "start_lost", "stop_gained")

##sco_fun5 changed on Aug-11-2019 to further underweight last exon variants (aftermath of POT1 variants in MGRB)
##sco_fun5 changed on Sept-05-2019 to further underweight variants that are C4 and present in the last
## 5% of the C-terminal tail of the protein.(aftermath of POT1 variants in MGRB)
sco_fun5 <- function(filt3_inp){
##construct C5,C4, C3 and score them as sco_fun4  
  ##All clinvar_sig variants
  filt3_inp$vep_con1 <- unlist(lapply(strsplit(filt3_inp$vep_consequence, split = "&"), function(x)x[1]))
  metric1 <-  ifelse(grepl(paste(toMatch1,collapse="|"), 
                           filt3_inp$clinvar_Clinical_Significance) , "C5", 
                     ifelse(grepl(paste(toMatch2,collapse="|"), 
                                  filt3_inp$vep_con1), "C4", 
                            ifelse(filt3_inp$vep_con1 %in% 
                                     c("missense_variant", "splice_region_variant",
                                       "splice_donor_variant", "splice_acceptor_variant",
                                       "protein_altering_variant")
                                   & filt3_inp$gnomad_AF_NFE == 0, "C3", "B")))
   ##lapply(strsplit(var_type, split = "&"), function(x)x[1]) think about this

  metric2 <- as.numeric(ifelse(metric1 %in% "C5", 45, 
                    ifelse(metric1 %in% "C4", 45, 
                           ifelse(metric1 %in% "C3", filt3_inp$EigenPhred, 0))))
  
  metric2[is.na(metric2)] <- 0
  
  ##changed on Aug-11-2019: Adjust this outside the function later
  #metric3 <- as.numeric(ifelse(metric1 %in% "C4" & filt3_inp$last_exon == 1, -10, 0))
  #metric3 <- as.numeric(ifelse(metric1 %in% "C4" & filt3_inp$last_exon == 1, -25, 0))
  
  #met <- metric2 + metric3
  
  #met_df <- cbind.data.frame("auto_call" = metric1, "comb_score" = met )
  met_df <- cbind.data.frame("auto_call" = metric1, "comb_score" = metric2 )
  return(met_df)
}



##Experiments

##scoring function5
#DT_gene_tab_ISKS_MGRB_nCH_fil3 <- filt3_inp
Ex_tab_noCH_filt3 <- cbind.data.frame(Ex_tab_noCH_filt3, sco_fun5(Ex_tab_noCH_filt3))

##Changed on Aug12 after DT meeting
##for sept05_rect dataset
##DT nee suggestions: Oct-2-2019
##If C4 == ClinVar Benign; assign eigenphred score
toMatch_ben <- c("Benign", "Benign/Likely_benign")
Ex_tab_noCH_filt3$comb_score <- as.numeric(ifelse(grepl(paste(toMatch_ben,collapse="|"), 
                                                 Ex_tab_noCH_filt3$clinvar_Clinical_Significance) & 
                                             Ex_tab_noCH_filt3$auto_call %in% "C4", Ex_tab_noCH_filt3$EigenPhred,
                                           Ex_tab_noCH_filt3$comb_score))
#frameshift donot have eigenphred scores, hence they are assigned a score of 15 manually
Ex_tab_noCH_filt3$comb_score <- ifelse(is.na(Ex_tab_noCH_filt3$comb_score), 15, Ex_tab_noCH_filt3$comb_score)
##last 5 percent of protein sequence based score penalty
Cterm_C3_C4 <- c("C3", "C4")
Ex_tab_noCH_filt3$comb_score <- as.numeric(ifelse(Ex_tab_noCH_filt3$auto_call %in% Cterm_C3_C4 &
                                                    Ex_tab_noCH_filt3$last_five_perc == 1, (Ex_tab_noCH_filt3$comb_score)/2,
                                                  Ex_tab_noCH_filt3$comb_score))

##This section needs to be robust
##VAF filter: if DP >= 35 use VAF >= 0.3 else VAF > 0.25 (done earlier)
#if(Ex_tab_noCH_filt3$DP >= 35){
##remove 45andUp cancer cases
can269 <- read.delim("~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/test/Rep_set_variants/cancer_45UP_269.csv", sep = ",", header = F)
Ex_tab_noCH_filt3 <- Ex_tab_noCH_filt3[!(Ex_tab_noCH_filt3$SAMPLE %in% can269$V1),]

# Ex_tab_noCH_filt4 <- Ex_tab_noCH_filt3[Ex_tab_noCH_filt3$VAF >= 0.3 & Ex_tab_noCH_filt3$DP >= 35, ]
# Ex_tab_noCH_filt4 <- Ex_tab_noCH_filt4[Ex_tab_noCH_filt4$comb_score >= 5, ]
# Ex_tab_noCH_filt5 <- Ex_tab_noCH_filt3[Ex_tab_noCH_filt3$VAF >= 0.3 & Ex_tab_noCH_filt3$DP < 35, ]
# Ex_tab_noCH_filt5 <- Ex_tab_noCH_filt4[Ex_tab_noCH_filt5$comb_score >= 5, ]
# Ex_tab_noCH_filt4 <- Ex_tab_noCH_filt4[,c(1:9,11,15,17:18,20,23:25,30,53,57,59:68,72,124:130)]
# Ex_tab_noCH_filt5 <- Ex_tab_noCH_filt5[,c(1:9,11,15,17:18,20,23:25,30,53,57,59:68,72,124:130)]
# 
# Ex_tab_noCH_filt6 <- rbind.data.frame(Ex_tab_noCH_filt4, Ex_tab_noCH_filt5)
# Ex_tab_noCH_filt3_test <- Ex_tab_noCH_filt3[,c(1:9,11,15,17:18,20,23:25,30,53,57,59:68,72,124:130)]

##remove samples with multiple frameshift mutations in the same gene
library(tidyr)
library(dplyr)
t1 <- Ex_tab_noCH_filt3[Ex_tab_noCH_filt3$gene_symbol %in% "BRIP1",]
t1 <- t1[t1$comb_score >= 5,]
t1 <- t1[,c(1,9)]
#gather(t1, "SAMPLE", "gene_symbol") %>%
#  count(SAMPLE, gene_symbol) %>% group_by(SAMPLE, gene_symbol)

## frameshifts
#Ex_tab_noCH_filt3 %>% filter(gene_symbol %in% "BRIP1" & vep_consequence %in% "frameshift_variant") %>% group_by(SAMPLE, gene_symbol) %>% summarise(n = n()) 
t1 <- Ex_tab_noCH_filt3 %>% filter(vep_consequence %in% "frameshift_variant") %>% group_by(SAMPLE, gene_symbol) %>% summarise(n = n()) 

t2 <- as.data.frame(t1)

t3 <- t2[t2$n > 1,] #remove these variants by subsetting the frameshift variants from these genes in the corresponding samples before saving

Ex_tab_noCH_filt3_fs <- list()
for(j in 1:dim(t3)[1]){
  f1 <- Ex_tab_noCH_filt3[Ex_tab_noCH_filt3$SAMPLE %in% t3$SAMPLE[j] &
                            Ex_tab_noCH_filt3$gene_symbol %in% t3$gene_symbol[j],]
  Ex_tab_noCH_filt3_fs[[j]] <- f1[f1$vep_consequence %in% "frameshift_variant", ]
  
}
rm_fs <- do.call("rbind.data.frame", Ex_tab_noCH_filt3_fs)

## mis-sense
t1_mis <- Ex_tab_noCH_filt3 %>% filter(vep_consequence %in% "missense_variant") %>% group_by(SAMPLE, gene_symbol) %>% summarise(n = n()) 

t2_mis <- as.data.frame(t1_mis)

t3_mis <- t2_mis[t2_mis$n > 2,] #cull all samples with more than 2 mis sense variants per genes

Ex_tab_noCH_filt3_ms <- list()
for(j in 1:dim(t3_mis)[1]){
  f1 <- Ex_tab_noCH_filt3[Ex_tab_noCH_filt3$SAMPLE %in% t3_mis$SAMPLE[j] &
                            Ex_tab_noCH_filt3$gene_symbol %in% t3_mis$gene_symbol[j],]
  Ex_tab_noCH_filt3_ms[[j]] <- f1[f1$vep_consequence %in% "missense_variant", ]
  
}

rm_ms <- do.call("rbind.data.frame", Ex_tab_noCH_filt3_ms)
#rm_ms$filt_tab <- paste(rm_ms$SAMPLE, rm_ms$VARIANT, sep = "_")

##combine the sets to remove from 

rm_fin <- rbind.data.frame(rm_fs, rm_ms)
rm_fin$filt_tab <- paste(rm_fin$SAMPLE, rm_fin$VARIANT, sep = "_")

Ex_tab_noCH_filt3$filt_tab <- paste(Ex_tab_noCH_filt3$SAMPLE, Ex_tab_noCH_filt3$VARIANT, sep = "_")


Ex_tab_noCH_filt3_fin <- Ex_tab_noCH_filt3[!(Ex_tab_noCH_filt3$filt_tab %in% rm_fin$filt_tab),]

Ex_tab_noCH_filt3_fin <- Ex_tab_noCH_filt3_fin[,c(1:9,11,15,17:18,20,23:25,30,53,57,59:68,72,124:130)]

#Ex_tab_noCH_filt3_fin[Ex_tab_noCH_filt3_fin$gene_symbol %in% "POT1" & Ex_tab_noCH_filt3_fin$auto_call != "B",c(1,4,9:10,37:38)]

#Tag QC2 failed

Ex_tab_noCH_filt3_fin$QC2 <- ifelse(Ex_tab_noCH_filt3_fin$SAMPLE %in% QC2_dat_fail, "fail", "pass")

#remove benigns and QC2 failed samples

Ex_tab_noCH_filt3_fin_filt <- Ex_tab_noCH_filt3_fin[Ex_tab_noCH_filt3_fin$auto_call != "B",]
Ex_tab_noCH_filt3_fin_filt <- Ex_tab_noCH_filt3_fin_filt[Ex_tab_noCH_filt3_fin_filt$QC2 %in% "pass",]
Ex_tab_noCH_filt3_fin_filt$filt_tab <- paste(Ex_tab_noCH_filt3_fin_filt$SAMPLE, Ex_tab_noCH_filt3_fin_filt$VARIANT, sep = "_")

##remove samples with more than 2 variants per gene
t_msfs <- Ex_tab_noCH_filt3_fin_filt %>% group_by(SAMPLE, gene_symbol) %>% summarise(n = n())
tdf_msfs <- as.data.frame(t_msfs[t_msfs$n > 2, ])
Ex_tab_noCH_filt3_msfs <- list()
for(j in 1:dim(tdf_msfs)[1]){
  Ex_tab_noCH_filt3_msfs[[j]] <- Ex_tab_noCH_filt3_fin_filt[Ex_tab_noCH_filt3_fin_filt$SAMPLE %in% tdf_msfs$SAMPLE[j] &
                                     Ex_tab_noCH_filt3_fin_filt$gene_symbol %in% tdf_msfs$gene_symbol[j],]
 # Ex_tab_noCH_filt3_msfs[[j]] <- f1[f1$vep_consequence %in% "missense_variant", ]
}
rm_ms_fs <- do.call("rbind.data.frame", Ex_tab_noCH_filt3_msfs)
rm_ms_fs$filt_tab <- paste(rm_ms_fs$SAMPLE, rm_ms_fs$VARIANT, sep = "_")
Ex_tab_noCH_filt3_fin_filt <- Ex_tab_noCH_filt3_fin_filt[!(Ex_tab_noCH_filt3_fin_filt$filt_tab %in% rm_ms_fs$filt_tab),]

##Intra-cohort MAF value
var_maf <- Ex_tab_noCH_filt3_fin_filt %>% group_by(VARIANT, gene_symbol) %>% summarise(n = n())
var_maf_df <- as.data.frame(var_maf)
var_maf_df <- var_maf_df[var_maf_df$n > 1, ]

##572 ISKS, 1039 MGRB
maf_list <- list()
for(j in 1:dim(var_maf_df)[1]){
  print(j)
  sam_var <- Ex_tab_noCH_filt3_fin_filt[Ex_tab_noCH_filt3_fin_filt$VARIANT %in% var_maf_df$VARIANT[j] 
                                        &  Ex_tab_noCH_filt3_fin_filt$gene_symbol %in% var_maf_df$gene_symbol[j], ]
  print(dim(sam_var))
  sam_var_vec <- ifelse(!is.na(as.numeric(as.character(sam_var$SAMPLE))) | grepl("^CR|^LK", as.character(sam_var$SAMPLE)), 1, 0)
  print(length(sam_var_vec))
  MAF_case <- sum(sam_var_vec)/572
  MAF_control <- (length(sam_var_vec) - MAF_case)/1039
  c1 <- cbind.data.frame(var_maf_df$VARIANT[j], MAF_case, MAF_control)
  colnames(c1) <- c("VARIANT", "MAF_case", "MAF_control")
  maf_list[[j]] <- c1
}
maf_list_df <- do.call("rbind.data.frame", maf_list)
Ex_tab_noCH_filt3_fin_filt$MAF_case <- maf_list_df[match(Ex_tab_noCH_filt3_fin_filt$VARIANT, maf_list_df$VARIANT),2]
Ex_tab_noCH_filt3_fin_filt$MAF_control <- maf_list_df[match(Ex_tab_noCH_filt3_fin_filt$VARIANT, maf_list_df$VARIANT),3]
Ex_tab_noCH_filt3_fin_filt$is_case <- ifelse(!is.na(as.numeric(as.character(Ex_tab_noCH_filt3_fin_filt$SAMPLE))) | 
                  grepl("^CR|^LK",as.character(Ex_tab_noCH_filt3_fin_filt$SAMPLE)), 1, 0)
Ex_tab_noCH_filt3_fin_filt$MAF_case <- ifelse((is.na(Ex_tab_noCH_filt3_fin_filt$MAF_case) 
                                              & Ex_tab_noCH_filt3_fin_filt$is_case == 1),
                                              1/572, Ex_tab_noCH_filt3_fin_filt$MAF_case)
Ex_tab_noCH_filt3_fin_filt$MAF_control <- ifelse((is.na(Ex_tab_noCH_filt3_fin_filt$MAF_control) 
                                               & Ex_tab_noCH_filt3_fin_filt$is_case == 0),
                                              1/1039, Ex_tab_noCH_filt3_fin_filt$MAF_control)
Ex_tab_noCH_filt3_fin_filt$MAF_case <- ifelse(is.na(Ex_tab_noCH_filt3_fin_filt$MAF_case), 0, 
                                               Ex_tab_noCH_filt3_fin_filt$MAF_case)
Ex_tab_noCH_filt3_fin_filt$MAF_control <- ifelse(is.na(Ex_tab_noCH_filt3_fin_filt$MAF_control), 0,
                                                 Ex_tab_noCH_filt3_fin_filt$MAF_control)

#Ex_tab_noCH_filt3_fin_filt[Ex_tab_noCH_filt3_fin_filt$gene_symbol %in% "POT1" & 
#                             Ex_tab_noCH_filt3_fin_filt$auto_call != "B",c(1,4,9:10,37:38)]
                                                  
write.table(Ex_tab_noCH_filt3_fin_filt[,-c(40,43)], file = "~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/test/Rep_set_variants/Rep_set_2044_C5eqC4_nonmds_iskrisclions_Oct08_filt_all.tsv",
        row.names = F, quote = F)
#write.table(Ex_tab_noCH_filt5, file = "~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/test/Rep_set_variants/Rep_set_2044_C5eqC4_nonmds_iskrisclions_Oct08_dp_lt35.tsv",
#            row.names = F, quote = F)
saveRDS(Ex_tab_noCH_filt3_fin, file = "~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/test/Rep_set_variants/Rep_set_2044_C5eqC4_nonmds_iskrisclions_Oct08_rect_ASP_new_score.rds", compress = T)


#########QC
#var_check <- read.delim("~/RVAS/shard_sub_tier3/DT_sheet/EXOME_isks_risc/var_control_set_Aug12.tsv", sep = "\t",
#           header = T)

#table(var_check$VARIANT %in% Ex_tab_noCH_filt3$VARIANT)