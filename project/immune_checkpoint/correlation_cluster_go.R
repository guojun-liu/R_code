library(clusterProfiler)
library(ComplexHeatmap)
library(circlize)
library(org.Hs.eg.db)
library(annotables)
library(pathview)
library(RColorBrewer)
library(scales)

setwd("/Users/stead/Desktop/PD-L1_and_TMI_type/correlation_and_go_cluster")

cancer="GBM"
color_type_table <- read.table(file = "/Users/stead/Desktop/PD-L1_and_TMI_type/color.txt", sep = "\t", stringsAsFactors = FALSE)
color_type <- color_type_table$V2
immune_path <- read.table(file = "/Users/stead/Desktop/PD-L1_and_TMI_type/immune_pathway/immune_pathway.txt", sep = "\t")
####################################################
#get cancer exprssion 
#get the number of mutation and neo-ag
####################################################

####cancer expression and convert
rt <- read.table(file = paste("/Users/stead/Desktop/PD-L1_and_TMI_type/", cancer, "/RNA_seq/TCGA-", cancer, ".htseq_fpkm.tsv", sep = ""),
                 sep = "\t", header = TRUE, row.names = 1, stringsAsFactors = FALSE)
row.names(rt) <- matrix(unlist(strsplit(row.names(rt), "[.]")), ncol = 2, byrow = TRUE)[, 1]
eg = bitr(row.names(rt), fromType="ENSEMBL", toType="ENTREZID", OrgDb="org.Hs.eg.db")
rt_ent <- merge(eg, cbind(row.names(rt), rt), by = 1)[, -1] 
###there are many duplication genes in rt_sym

source("/Users/stead/Desktop/PD-L1_and_TMI_type/scripts/get_tcga_sample_type.R")
rt_T <- split_tcga_tn(rt_ent[, -1], sam_type = "tumor", split_type = "[.]")
#rt_N <- split_tcga_tn(rt_ent[, -1], sam_type = "normal")

###CTLA4 entrezid is 1493
CTLA4 <- as.numeric(rt_T[which(rt_ent$ENTREZID == "1493"), ])
names(CTLA4) <- colnames(rt_T)
#29126
PDL1 <- as.numeric(rt_T[which(rt_ent$ENTREZID == "29126"), ])
names(PDL1) <- colnames(rt_T)
#5133
PD1  <- as.numeric(rt_T[which(rt_ent$ENTREZID == "5133"), ])
names(PD1) <- colnames(rt_T)
#50943
#FOXP3 <- as.numeric(rt_T[which(rt_ent$ENTREZID == "50943"), ])
#names(FOXP3) <- colnames(rt_T)


get_high_cor_gene <- function(in_gene, gene_exp, in_mat, cutoff){
  test_gene_exp <- as.numeric(in_mat[in_gene, ])
  if(all(test_gene_exp == 0)){
    return(NULL)
  }
  
  if(any(test_gene_exp != 0)){
    cor_value = round(cor(gene_exp, test_gene_exp), 2)
    if(cor_value > cutoff){
      gene_value <- c(in_gene, cor_value)
      return (gene_value)
    } else {
      gene_value <- c(in_gene, cor_value)
      return(NULL)
    } 
  }
}

###############################################
#get pathway type and matrix
################################################
###usage: mat_type_list_CTLA4 <- GetPathwayGene(rt_T, CTLA4, 0.4)
GetPathwayGene <- function(rt_KK, gene_exp, cutoff){
  #rt_KK is a data.frame 
  #gene_exp is an gene expression vector, such as CTLA4
  #cutoff is correlation value which was set to filter 
  in_gene = c(row.names(rt_KK))
  cor_gene_list <- lapply(in_gene, get_high_cor_gene, gene_exp, rt_KK, cutoff)
  rt_cor_gene <- do.call(rbind, cor_gene_list)
  gene <- rt_ent$ENTREZID[as.numeric(rt_cor_gene[, 1])]
  
  kk <- enrichKEGG(gene = gene, organism = 'hsa', pvalueCutoff = 0.05)
  print(head(kk))
  path_M <- intersect(kk@result$ID, immune_path$V1)
  rt_path <- kk@result[, c("ID", "Description", "geneID", "Count")][match(path_M, kk@result$ID, nomatch = 0), ]
  
  ###kk genes and pathway type
  path_gene <- unlist(strsplit(rt_path$geneID, "/"))
  mat_path <- rt_KK[match(path_gene, rt_ent$ENTREZID, nomatch = 0), ]
  
  get_path_type <- function(rt_path){
    path_type <- rep(rt_path$Description[1], rt_path$Count[1])
    for(i in 2: length(rt_path$Description)){
      path_type <- c(path_type, rep(rt_path$Description[i], rt_path$Count[i]))
    }
    return(path_type)
  }
  
  path_type <- get_path_type(rt_path)
  names(path_type) <- path_gene
  mat_type_list <- list(mat_path, path_type)
}



#########################################################
#clinical ddta
#
#########################################################
rt_cli <- read.table(file = paste("/Users/stead/Desktop/PD-L1_and_TMI_type/", cancer, "/phenotype/TCGA-", cancer, ".GDC_phenotype.tsv", sep = ""),
                 sep = "\t", header = TRUE, row.names = NULL, stringsAsFactors = FALSE, fill = TRUE, quote = "", na.strings = "NA")
sam_cli <- matrix(unlist(strsplit(rt_cli$submitter_id.samples, "-")), ncol = 4, byrow = TRUE)
rt_cli$submitter_id.samples <- paste(sam_cli[, 1], sam_cli[, 2], sam_cli[, 3], sep = "-")


#########################################################
#draw heatmap based on CTLA4 order
#
#########################################################
mat_type_list_CTLA4 <- GetPathwayGene(rt_T, CTLA4, 0.4)
mat_path_CTLA4 <- mat_type_list_CTLA4[[1]]
path_type_CTLA4 <- mat_type_list_CTLA4[[2]]

###reorder three genes base on CTAL4 order
order_CTLA4 <- order(CTLA4)
CTLA4_CTLA4 <- CTLA4[order_CTLA4]
PDL1_CTLA4 <- PDL1[order(CTLA4)]
PD1_CTLA4 <- PD1[order(CTLA4)]

mat_path_CTLA4 <- mat_path_CTLA4[, order_CTLA4]
mat_scaled_CTLA4 = t(apply(mat_path_CTLA4, 1, scale))

##################reorder clinical data#################
pair_sam_CTLA4<- match(names(CTLA4_CTLA4), rt_cli$submitter_id.samples, nomatch = 0)
rt_cli_CTLA4 <- rt_cli[pair_sam_CTLA4, ]
rt_cli_age_CTLA4 <- as.numeric(rt_cli_CTLA4$age_at_initial_pathologic_diagnosis) 
rt_cli_age_CTLA4[which(rt_cli_age_CTLA4 == "")] = NA
rt_cli_gender_CTLA4 <- rt_cli_CTLA4$gender.demographic
rt_cli_gender_CTLA4[which(rt_cli_gender_CTLA4 == "")] = NA
#rt_cli_stage <- rt_cli_CTLA4$tumor_stage.diagnoses
#rt_cli_stage[which(rt_cli_stage == "")] = NA
#rt_cli_race <- rt_cli_CTLA4$race.demographic
#rt_cli_race[which(rt_cli_race == "")] = NA

##################do complex heatmap###################
CTLA4_ha1 = HeatmapAnnotation(PDL1 = PDL1_CTLA4, PD1 = PD1_CTLA4, CTLA4 = CTLA4_CTLA4, 
                        col = list(PDL1 = colorRamp2(c(0, max(PDL1_CTLA4)/2), c("white", color_type[3])),
                                   PD1 = colorRamp2(c(0, max(PD1_CTLA4)/2), c("white", color_type[4])),
                                   CTLA4 = colorRamp2(c(0, max(CTLA4_CTLA4)/2), c("white", color_type[5]))))
CTLA4_ha2 = HeatmapAnnotation(gender = rt_cli_gender_CTLA4, 
                        age = anno_points(rt_cli_age_CTLA4, gp = gpar(col = ifelse(rt_cli_age_CTLA4 > 60, "black", "red")), axis = TRUE), 
                        col = list(gender = structure(names = c("male", "female", "NA"), c("#377EB8", "#FFFF33", "#FF7F00"))), 
                        annotation_height = unit(c(5, 30), "mm"))

pdf(file = paste(cancer, "_KEGG_cluster_CTLA4.pdf", sep = ""), 10, 10)
ht_list_CTLA4 <- Heatmap(path_type_CTLA4, width = unit(0.5, "cm"), show_row_names = FALSE, show_column_names = FALSE, name = "pathway_type", col = color_type[1 : length(unique(path_type_CTLA4))]) +
           Heatmap(mat_scaled_CTLA4, name = "expression", col = colorRamp2(c(-5 , 0, 5), c(" blue", "white", "red")),
                   top_annotation = CTLA4_ha1, bottom_annotation = CTLA4_ha2, top_annotation_height = unit(2, "cm"), 
                   cluster_columns = FALSE, column_dend_reorder = FALSE, 
                   cluster_rows = FALSE, row_dend_reorder = FALSE, 
                   show_row_dend = FALSE, show_column_dend = FALSE,
                   show_row_names = FALSE, show_column_names = FALSE) 
draw(ht_list_CTLA4, annotation_legend_side = "right", heatmap_legend_side = "right")
dev.off()



#########################################################
#draw heatmap based on PDL1 order
#
#########################################################
mat_type_list_PDL1 <- GetPathwayGene(rt_T, PDL1, 0.4)
mat_path_PDL1 <- mat_type_list_PDL1[[1]]
path_type_PDL1 <- mat_type_list_PDL1[[2]]

###based on PDL1 order
order_PDL1 <- order(PDL1)
CTLA4_PDL1 <- CTLA4[order_PDL1]
PDL1_PDL1 <- PDL1[order(PDL1)]
PD1_PDL1 <- PD1[order(PDL1)]

mat_path_PDL1 <- mat_path_PDL1[, order_PDL1]
mat_scaled_PDL1 = t(apply(mat_path_PDL1, 1, scale))

##################reorder clinical data#################
pair_sam_PDL1<- match(names(PDL1_PDL1), rt_cli$submitter_id.samples, nomatch = 0)
rt_cli_PDL1 <- rt_cli[pair_sam_PDL1, ]
rt_cli_age_PDL1 <- as.numeric(rt_cli_PDL1$age_at_initial_pathologic_diagnosis) 
rt_cli_age_PDL1[which(rt_cli_age_PDL1 == "")] = NA
rt_cli_gender_PDL1 <- rt_cli_PDL1$gender.demographic
rt_cli_gender_PDL1[which(rt_cli_gender_PDL1 == "")] = NA
#rt_cli_stage <- rt_cli_PDL1$tumor_stage.diagnoses
#rt_cli_stage[which(rt_cli_stage == "")] = NA
#rt_cli_race <- rt_cli_PDL1$race.demographic
#rt_cli_race[which(rt_cli_race == "")] = NA

##################do complex heatmap###################
PDL1_ha1 = HeatmapAnnotation(PDL1 = PDL1_PDL1, PD1 = PD1_PDL1, CTLA4 = CTLA4_PDL1, 
                              col = list(PD1 = colorRamp2(c(0, max(PD1_PDL1)/2), c("white", color_type[4])),
                                         CTLA4 = colorRamp2(c(0, max(CTLA4_PDL1)/2), c("white", color_type[5])),
                                         PDL1 = colorRamp2(c(0, max(PDL1_PDL1)/2), c("white", color_type[3]))))
PDL1_ha2 = HeatmapAnnotation(gender = rt_cli_gender_PDL1, 
                              age = anno_points(rt_cli_age_PDL1, gp = gpar(col = ifelse(rt_cli_age_PDL1 > 60, "black", "red")), axis = TRUE), 
                              col = list(gender = structure(names = c("male", "female", "NA"), c("#377EB8", "#FFFF33", "#FF7F00"))), 
                              annotation_height = unit(c(5, 30), "mm"))

pdf(file = paste(cancer, "_KEGG_cluster_PDL1.pdf", sep = ""), 10, 10)
ht_list_PDL1 <- Heatmap(path_type_PDL1, width = unit(0.5, "cm"), show_row_names = FALSE, show_column_names = FALSE, name = "pathway_type", col = color_type[1 : length(unique(path_type_PDL1))]) +
  Heatmap(mat_scaled_PDL1, name = "expression", col = colorRamp2(c(-5 , 0, 5), c(" blue", "white", "red")),
          top_annotation = PDL1_ha1, bottom_annotation = PDL1_ha2, top_annotation_height = unit(2, "cm"), 
          cluster_columns = FALSE, column_dend_reorder = FALSE, 
          cluster_rows = FALSE, row_dend_reorder = FALSE, 
          show_row_dend = FALSE, show_column_dend = FALSE,
          show_row_names = FALSE, show_column_names = FALSE) 
draw(ht_list_PDL1, annotation_legend_side = "right", heatmap_legend_side = "right")
dev.off()


#########################################################
#draw heatmap based on PD1 order
#
#########################################################
mat_type_list_PD1 <- GetPathwayGene(rt_T, PD1, 0.4)
mat_path_PD1 <- mat_type_list_PD1[[1]]
path_type_PD1 <- mat_type_list_PD1[[2]]

###based on PD1 order
order_PD1 <- order(PD1)
CTLA4_PD1 <- CTLA4[order_PD1]
PDL1_PD1 <- PDL1[order(PD1)]
PD1_PD1 <- PD1[order(PD1)]

mat_path_PD1 <- mat_path_PD1[, order_PD1]
mat_scaled_PD1 = t(apply(mat_path_PD1, 1, scale))

##################reorder clinical data#################
pair_sam_PD1<- match(names(PD1_PD1), rt_cli$submitter_id.samples, nomatch = 0)
rt_cli_PD1 <- rt_cli[pair_sam_PD1, ]
rt_cli_age_PD1 <- as.numeric(rt_cli_PD1$age_at_initial_pathologic_diagnosis) 
rt_cli_age_PD1[which(rt_cli_age_PD1 == "")] = NA
rt_cli_gender_PD1 <- rt_cli_PD1$gender.demographic
rt_cli_gender_PD1[which(rt_cli_gender_PD1 == "")] = NA
#rt_cli_stage <- rt_cli_PD1$tumor_stage.diagnoses
#rt_cli_stage[which(rt_cli_stage == "")] = NA
#rt_cli_race <- rt_cli_PD1$race.demographic
#rt_cli_race[which(rt_cli_race == "")] = NA

##################do complex heatmap###################
PD1_ha1 = HeatmapAnnotation(PDL1 = PDL1_PD1, PD1 = PD1_PD1, CTLA4 = CTLA4_PD1, 
                             col = list(PDL1 = colorRamp2(c(0, max(PDL1_PD1)/2), c("white", color_type[3])),
                                        CTLA4 = colorRamp2(c(0, max(CTLA4_PD1)/2), c("white", color_type[5])),
                                        PD1 = colorRamp2(c(0, max(PD1_PD1)/2), c("white", color_type[4]))))

PD1_ha2 = HeatmapAnnotation(gender = rt_cli_gender_PD1, 
                             age = anno_points(rt_cli_age_PD1, gp = gpar(col = ifelse(rt_cli_age_PD1 > 60, "black", "red")), axis = TRUE), 
                             col = list(gender = structure(names = c("male", "female", "NA"), c("#377EB8", "#FFFF33", "#FF7F00"))), 
                             annotation_height = unit(c(5, 30), "mm"))

pdf(file = paste(cancer, "_KEGG_cluster_PD1.pdf", sep = ""), 10, 10)
ht_list_PD1 <- Heatmap(path_type_PD1, width = unit(0.5, "cm"), show_row_names = FALSE, show_column_names = FALSE, name = "pathway_type", col = color_type[1 : length(unique(path_type_PD1))]) +
  Heatmap(mat_scaled_PD1, name = "expression", col = colorRamp2(c(-5 , 0, 5), c(" blue", "white", "red")),
          top_annotation = PD1_ha1, bottom_annotation = PD1_ha2, top_annotation_height = unit(2, "cm"), 
          cluster_columns = FALSE, column_dend_reorder = FALSE, 
          cluster_rows = FALSE, row_dend_reorder = FALSE, 
          show_row_dend = FALSE, show_column_dend = FALSE,
          show_row_names = FALSE, show_column_names = FALSE) 
draw(ht_list_PD1, annotation_legend_side = "right", heatmap_legend_side = "right")
dev.off()

#################################################
#you can choose when your data 
#contain more clinical information
#
################################################
#ha1 = HeatmapAnnotation(df = data.frame(CTLA4_O), col = list(CTLA4_O = colorRamp2(c(0, max(CTLA4_O)/2), c("white", "red"))))
#ha2 = HeatmapAnnotation(gender = rt_cli_gender, stage = rt_cli_stage, race = rt_cli_race, 
#                        age = anno_points(rt_cli_age, gp = gpar(col = ifelse(rt_cli_age > 60, "black", "red")), axis = TRUE), 
#                        col = list(gender = structure(names = c("male", "female", "NA"), c("#377EB8", "#FFFF33", "#FF7F00")), 
#                                   race = structure(names = c("white", "asian", "black or african american", "not reported", "NA"), brewer.pal(5, "Set1")), 
#                                   stage = structure(names = c("not reported", "NA"), c("white", "#E41A1C"))), 
#                        annotation_height = unit(c(5, 5, 5, 30), "mm"))
#
#pdf(file = "GBM_KEGG_cluster.pdf", 10, 10)
#ht_list <- Heatmap(path_type, width = unit(0.5, "cm"), show_row_names = FALSE, show_column_names = FALSE, name = "pathway_type", col = rainbow(5)) +
#  Heatmap(mat_scaled, name = "expression", col = colorRamp2(c(-5 , 0, 5), c(" blue", "white", "red")),
#          top_annotation = ha1, bottom_annotation = ha2, top_annotation_height = unit(4, "mm"), 
#          cluster_columns = FALSE, column_dend_reorder = FALSE, 
#          cluster_rows = FALSE, row_dend_reorder = FALSE, 
#          show_row_dend = FALSE, show_column_dend = FALSE,
#          show_row_names = FALSE, show_column_names = FALSE) 
#draw(ht_list, annotation_legend_side = "right", heatmap_legend_side = "right")
#dev.off()
#################################################
#################################################

####go analsis
#ggo_CC <- groupGO(gene = gene, OrgDb = org.Hs.eg.db, on = "CC", level = 3, readable = TRUE)
#pdf(file = paste(cancer, "_ggo_CC.pdf"), 8, 8)
#barplot(ggo, drop = TRUE, showCategory = 30)
#dev.off()
#ggo_CC_results <- ggo_CC@result
#write.table(ggo_CC_results,file = paste(cancer, "_ggo_CC.txt"), sep = "\t")
#
#ggo_BP <- groupGO(gene = gene, OrgDb = org.Hs.eg.db, on = "BP", level = 3, readable = TRUE)
#pdf(file = paste(cancer, "_ggo_BP.pdf"), 8, 8)
#barplot(ggo_BP, drop = TRUE, showCategory = 30)
#dev.off()
#ggo_BP_results <- ggo_BP@result
#write.table(ggo_BP_results,file = paste(cancer, "_ggo_BP.txt"), sep = "\t")

#ggo_MF <- groupGO(gene = gene, OrgDb = org.Hs.eg.db, on = "MF", level = 3, readable = TRUE)
#pdf(file = paste(cancer, "_ggo_MF.pdf"), 8, 8)
#barplot(ggo, drop=TRUE, showCategory = 30)
#dev.off()
#ggo_MF_results <- ggo_MF@result
#write.table(ggo_MF_results,file = paste(cancer, "_ggo_MF.txt"), sep = "\t")
