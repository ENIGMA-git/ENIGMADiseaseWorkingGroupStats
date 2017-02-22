##if you don't have certain packages installed you may need to install them to your homedir and point R to them
#install.packages("metafor", lib="/ifshome/cching/r_packs", repos="http://cran.r-project.org")
#install.packages("bitops", lib="/ifshome/cching/r_packs", repos="http://cran.r-project.org")
#library(bitops, lib.loc="/ifshome/cching/r_packs")
#install.packages("RCurl", lib="/ifshome/cching/r_packs", dependencies = TRUE, repos="http://cran.r-project.org")


library(bitops, lib.loc="/ifshome/cching/r_packs/")
library(metafor, lib.loc="/ifshome/cching/r_packs/")
library(RCurl,lib.loc="/ifshome/cching/r_packs/")
#library(RCurl,lib.loc="/ifshome/disaev/R/x86_64-pc-linux-gnu-library/3.2/")
#library(RCurl, lib.loc="/usr/local/R-3.1.3/lib64/R/library")
#library(RCurl, lib.loc="/ifshome/cching/r_packs")

#library(metafor)
#--0.
require(RCurl)

read_web_csv<-function(url_address){
  gdoc3=paste(url_address,'/export?format=csv&id=KEY',sep='')
  myCsv <- getURL(gdoc3,.opts=list(ssl.verifypeer=FALSE))
  csv_res<-read.csv(textConnection(myCsv),header = TRUE,stringsAsFactors = FALSE)
  return (csv_res)
}

getMainFactorString<-function(strMainFactor){
  if(length(grep(".*:.*",strMainFactor))>0){
    fInteract=strsplit(strMainFactor,':')[[1]]
  }
  else {
    fInteract=strMainFactor
  }
  for (c in 1:length(fInteract)){
    #    fInteract[c]=str_replace_all(fInteract[c],"\\(","\\\\(")
    #    fInteract[c]=str_replace_all(fInteract[c],"\\)","\\\\)")
    fInteract[c]=gsub("\\(","\\\\(",fInteract[c])
    fInteract[c]=gsub("\\)","\\\\)",fInteract[c])
    fInteract[c]=paste(fInteract[c],'.*',sep='')
  }
  strRegexp=paste(fInteract,collapse=':')
  return(strRegexp)
}

getTstatFactorName<-function(coeffFactorName,rowCoeffNames){
  
  coeffName=getMainFactorString(coeffFactorName)
  for (i in 1:length(rowCoeffNames)) {
    factorName=grep(coeffName,rowCoeffNames[i],value=TRUE)
    if (length(factorName)!=0) break
  }
  if(length(factorName)==0) {
    print(paste("Couldn't find a factor for: ", coeffName,sep=''))
    return(character(0))
  }
  return(factorName)
}

#--0.
#--1. READING THE COMMAND LINE---

cmdargs = commandArgs(trailingOnly=T)
ID=cmdargs[1]
RUN_ID=ID
resDir=cmdargs[2]
Results_CSV_Path<-paste(resDir,'/',RUN_ID,'_ALL',sep='')
#Results_CSV_Path<-"res"

logDir=cmdargs[3]
#LOG_FILE<-"logfile_meta.log"

NVertex=as.numeric(cmdargs[4])
#NVertex=2502

#Using 1 CUR_ROI instead of ROI_LIST

#ROI_LIST_TXT=cmdargs[5]
#ROI_LIST<-readChar(ROI_LIST_TXT, file.info(ROI_LIST_TXT)$size)
#ROI_LIST
#ROINames<-eval(parse(text=paste('c(',ROI_LIST,')',sep='')))
#NROIS=length(ROINames)
#ROINames=c("ACR","ACR_L","ACR_R","ALIC","ALIC_L","ALIC_R","AverageFA","BCC","CC","CGC","CGC_L","CGC_R","CGH","CGH_L","CGH_R","CR","CR_L","CR_R","CST","CST_L","CST_R","EC","EC_L","EC_R","FX","FX_ST_L","FX_ST_R","FXST","GCC","IC","IC_L","IC_R","IFO","IFO_L","IFO_R","PCR","PCR_L","PCR_R","PLIC","PLIC_L","PLIC_R","PTR","PTR_L","PTR_R","RLIC","RLIC_L","RLIC_R","SCC","SCR","SCR_L","SCR_R","SFO","SFO_L","SFO_R","SLF","SLF_L","SLF_R","SS","SS_L","SS_R","UNC","UNC_L","UNC_R")
#ROINames<-c("10","11","12","13","17","18","26","49","50","51","52","53","54","58")

CUR_ROI=cmdargs[5]
NROIS=1
ROINames<-c(CUR_ROI)
LOG_FILE<-paste(logDir, '/',RUN_ID,'_',CUR_ROI,'_meta.log',sep='')
#create log file
messages=file(LOG_FILE, open="wt")
#rest=file("rest.Rout", open="wt")
sink(messages, type="message")
sink(messages, type="output")

SITE_LIST_TXT=cmdargs[6]
SITE_LIST<-readChar(SITE_LIST_TXT, file.info(SITE_LIST_TXT)$size)
SITE_LIST
Sites<-eval(parse(text=paste('c(',SITE_LIST,')',sep='')))
#Sites=c('studyIndiana','studyDublin','studyGalway')

Config_Path=cmdargs[7]   #docs.google 
config_csv<-read_web_csv(Config_Path)
config_currentRun<-config_csv[grep(ID, config_csv$ID, ignore.case=T),]
if(nrow(config_currentRun)>1) {
  cat (paste("Error: number of rows with ID ",ID," is more than 1. Row must be unique.",sep=''))
  stop()
}


AnalysisList_Path<-config_currentRun$AnalysisList_Path
DemographicsList_Path<-config_currentRun$DemographicsList_Path
#AnalysisList_Path<-"lm_config.csv" #list of linear models with IDs. takes filenames from this file.


cat(paste("Analysis list path: ",AnalysisList_Path,sep=''))
TYPE<-config_currentRun$Type
TRAIT_LIST<-config_currentRun$Trait
TRAIT_LIST<-gsub("[[:space:]]", "", TRAIT_LIST)
TRAIT_LIST<-gsub(";","\",\"",TRAIT_LIST)
SHAPE_METRICS<-eval(parse(text=paste('c("',TRAIT_LIST,'")',sep='')))
#SHAPE_METRICS<-c("LogJacs","thick")



#1. CONSTANTS FOR THE SCRIPT
#ModelName=''

#cur_SM="LogJacs"
#curModelName="SZPatVsCont"
FDR_threshold=0.05
#FDR by NEDA
FDR = function(p,q) {
  p = sort(p);
  V = length(p);
  I = seq(1,V);
  cVID = 1;
  if (length(which(p <= I/V*q/cVID))>0) {
    pID = p[max(which(p <= I/V*q/cVID))];
  } else {
    pID = -Inf;
  }
  return(pID);
}

#2. INITIALIZING VARIABLES
cohensDs=array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
SEs=array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
Nctl=array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
Npat=array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))

betas=list()
betas_se=list()
meta_b=list()
meta_b_se=list()
meta_b_zval=list()
meta_b_pval=list()
meta_b_ci.lb=list()
meta_b_ci.ub=list()
meta_b_tau2=list()
meta_b_tause=list()
meta_b_i2=list()
meta_b_h2=list()

analyze_betas=TRUE

meta_d=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_se=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_zval=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_pval=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_ci.lb=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_ci.ub=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_tau2=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_tause=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_i2=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_h2=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_nctl=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
meta_npat=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))

dsAnalysisConf<-read_web_csv(AnalysisList_Path)

#3. Reading each site's data

factorOfInterest=NA
factOfIntName=NA

# Stuff for running several metaanalyses - for a number of Shape metrics and 
for (cur_SM in SHAPE_METRICS){
  cat(paste("Reading Shape Metrics: ", cur_SM, "\n",sep=''))
  for (cur_rowAnalysis in 1:nrow(dsAnalysisConf)){
    if (dsAnalysisConf$Active[cur_rowAnalysis]==0) {next}
    result = tryCatch({	
    cohensDs=array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
    SEs=array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
    Nctl=array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
    Npat=array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
    
    meta_d=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_se=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_zval=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_pval=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_ci.lb=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_ci.ub=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_tau2=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_tause=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_i2=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_h2=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_nctl=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    meta_npat=matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
    
	betas=list()
	betas_se=list()
	meta_b=list()
	meta_b_se=list()
	meta_b_zval=list()
	meta_b_pval=list()
	meta_b_ci.lb=list()
	meta_b_ci.ub=list()
	meta_b_tau2=list()
	meta_b_tause=list()
	meta_b_i2=list()
	meta_b_h2=list()

    curModelName=dsAnalysisConf$ID[cur_rowAnalysis]
    cat(paste("SM:",cur_SM, " + Model: ", curModelName,'\n',sep=''))   
    cat("Readings Cohens D et al...")
    betanames_init=FALSE
    for (i_s in 1:length(Sites)) {
      site=Sites[i_s]
      cat(paste("Site ",site,'...',sep=''))
      #  file=paste(site,ModelName,"/EffectSizes.Rdata",sep="")
      file=paste(Results_CSV_Path,'_',cur_SM,'_',curModelName,'_',site,'.csv',sep='') #res_FA_SZ_DiagBySexInt.csv
      cat(paste("File ",file,sep=''))
      if (!(file.exists(file))) {
	cat(paste("No data file for SM:",cur_SM, " Model: ", curModelName," Site: ",site, "ROI: ",CUR_ROI,". Proceeding to the next Site.", '\n',sep=''))   
	next
      }
      data=read.csv(file, header=TRUE)
      data=data[data$ROI==CUR_ROI,]
      if(!betanames_init) {
        betanames_init<-TRUE
        beta_names_full=names(data)[grepl("beta_",names(data))]
        betase_names_full=names(data)[grepl("st_err_",names(data))]
        
        beta_names=sub("beta_","",beta_names_full)
        betase_names=sub("st_err_","",betase_names_full)
	
factorOfInterest<<-sub("\\(",".",dsAnalysisConf$FactorOfInterest[cur_rowAnalysis])
factorOfInterest<<-sub("\\)",".",factorOfInterest)

    factOfIntName<<-getTstatFactorName(factorOfInterest,beta_names)
    cat(paste("factor of interest: ", factOfIntName,"\n",sep=''))        

        if (!( (length(beta_names)==length(betase_names)) && (sum(as.integer(beta_names==betase_names))==length(beta_names)) ) )
        {
          analyze_betas=FALSE
          cat("Fields 'beta_*' and 'st_err_*' do not match in source files! Betas won't be analyzed.")
          
        }
        for (elem in beta_names) {
          betas[[elem]]<-array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
          betas_se[[elem]]<-array(NA,dim=c(NVertex,NROIS,length(Sites)),dimnames=list(NULL,ROINames,NULL))
          meta_b[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_se[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_zval[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_pval[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_ci.lb[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_ci.ub[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_tau2[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_tause[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_i2[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
          meta_b_h2[[elem]]<-matrix(NA,NVertex,NROIS,dimnames=list(NULL,ROINames))
        }
      }
      #print(cohens_d[1:3])
      cat(paste("data length: ", length(data$ROI),sep=''))
      for (i in 1:length(data$ROI)){
        if (NVertex==1){
          cohensDs[1, toString(data$ROI[i]), i_s]=eval(parse(text=paste("data$",names(data)[grepl( "d_" , names( data ) )],"[i]",sep='')));
          SEs[1, toString(data$ROI[i]), i_s]=eval(parse(text=paste("data$",names(data)[grepl( "st_err.d._" , names( data ) )],"[i]",sep='')));
          Nctl[1,toString(data$ROI[i]),i_s]=data$n.controls[i];
          Npat[1,toString(data$ROI[i]),i_s]=data$n.patients[i];
          
          if(analyze_betas==TRUE) {
            for (elem in beta_names) {
              betas[[elem]][1,toString(data$ROI[i]), i_s]<-if(!is.null( eval(parse(text=paste("data$beta_",elem,"[i]",sep=''))) )) eval(parse(text=paste("data$beta_",elem,"[i]",sep=''))) else NA
              betas_se[[elem]][1,toString(data$ROI[i]), i_s]<-if(!is.null( eval(parse(text=paste("data$st_err_",elem,"[i]",sep=''))) )) eval(parse(text=paste("data$st_err_",elem,"[i]",sep=''))) else NA            }
          }
        }
        else {
          
          cohensDs[data$Vertex[i], toString(data$ROI[i]), i_s]=eval(parse(text=paste("data$",names(data)[grepl( "d_" , names( data ) )],"[i]",sep='')));
          SEs[data$Vertex[i], toString(data$ROI[i]), i_s]=eval(parse(text=paste("data$",names(data)[grepl( "st_err.d._" , names( data ) )],"[i]",sep='')));
          Nctl[data$Vertex[i],toString(data$ROI[i]),i_s]=data$n.controls[i];
          Npat[data$Vertex[i],toString(data$ROI[i]),i_s]=data$n.patients[i];
          if(analyze_betas==TRUE) {
            for (elem in beta_names) {
              betas[[elem]][data$Vertex[i],toString(data$ROI[i]), i_s]<-if(!is.null( eval(parse(text=paste("data$beta_",elem,"[i]",sep=''))) )) eval(parse(text=paste("data$beta_",elem,"[i]",sep=''))) else NA
              betas_se[[elem]][data$Vertex[i],toString(data$ROI[i]), i_s]<-if(!is.null( eval(parse(text=paste("data$st_err_",elem,"[i]",sep=''))) )) eval(parse(text=paste("data$st_err_",elem,"[i]",sep=''))) else NA

            }
          }
          
        }
        
      }
    }
    cat("Done.\n")
    cat("COMPUTING METAANALYSIS STATISTICS")
    #4. Computing metaanalysis statistics
    
    #    pbReadVertices <- txtProgressBar(1,NVertex,title='Reading vertices.')
    iPb=1  #counter for progress bar
    
    for (x in 1:NVertex){
      #      if (x %in% [1,500,1000,1500,2000,2300]) {
      #        cat(toString(x))
      #      }        
      
      for(y in 1:NROIS){
        yii=cohensDs[x,y,which(!is.na(cohensDs[x,y,]))]
        seii=SEs[x,y,which(!is.na(cohensDs[x,y,]))]
        studynames=Sites[which(!is.na(cohensDs[x,y,]))]	
        if (!(length(yii)==0 | length(seii)==0)) {
#		png(paste(resDir,'/',RUN_ID,'_',cur_SM,"_",curModelName,"_",ROINames[y],"_",as.character(x),".png",sep=""),500,500)
		
		res=rma.uni(yi=yii,sei=seii,slab=studynames,method="REML",control=list(stepadj=0.5,maxiter=10000))
#		forest(res)
		
#		dev.off()
		#        res=rma.uni(yi=yii,sei=seii,method="REML")
		meta_d[x,ROINames[y]] = res$b
		meta_se[x,ROINames[y]] = res$se
		meta_zval[x,ROINames[y]] = res$zval
		meta_pval[x,ROINames[y]] = res$pval
		meta_ci.lb[x,ROINames[y]] = res$ci.lb
		meta_ci.ub[x,ROINames[y]] = res$ci.ub
		meta_tau2[x,ROINames[y]] = res$tau2
		meta_tause[x,ROINames[y]] = res$se.tau2
		meta_i2[x,ROINames[y]] = res$I2
		meta_h2[x,ROINames[y]] = res$H2
		meta_nctl[x,ROINames[y]] = sum(Nctl[x,y,which(!is.na(cohensDs[x,y,]))])
		meta_npat[x,ROINames[y]] = sum(Npat[x,y,which(!is.na(cohensDs[x,y,]))])        
        }
	print(paste("length( yii: ), length( seii) : ",length(yii),length(seii),sep=' '))
        if(analyze_betas==TRUE){
		#cat(beta_names)

	        for (elem in beta_names) {
		  yii=betas[[elem]][x,y,which(!is.na(betas[[elem]][x,y,]))]
		  seii=betas_se[[elem]][x,y,which(!is.na(betas_se[[elem]][x,y,]))]
	          studynames=Sites[which(!is.na(betas[[elem]][x,y,]))]	
		  #cat(paste(as.character(x),":", as.character(y)," ",elem,as.character(betas[[elem]][x,y,1]),sep=''))
		  res=rma.uni(yi=yii,sei=seii,slab=studynames,method="REML",control=list(stepadj=0.5,maxiter=10000))

		  meta_b[[elem]][x,ROINames[y]] = res$b
		  meta_b_se[[elem]][x,ROINames[y]] = res$se
		  meta_b_zval[[elem]][x,ROINames[y]] = res$zval
		  meta_b_pval[[elem]][x,ROINames[y]] = res$pval
		  meta_b_ci.lb[[elem]][x,ROINames[y]] = res$ci.lb
		  meta_b_ci.ub[[elem]][x,ROINames[y]] = res$ci.ub
		  meta_b_tau2[[elem]][x,ROINames[y]] = res$tau2
		  meta_b_tause[[elem]][x,ROINames[y]] = res$se.tau2
		  meta_b_i2[[elem]][x,ROINames[y]] = res$I2
		  meta_b_h2[[elem]][x,ROINames[y]] = res$H2
		}
        }

      }
      #     setTxtProgressBar(pbReadVertices,iPb)      
      iPb=iPb+1
    }
    #   close(pbReadVertices)
    

    #5. Multiple comparisons correction.
    #5.1 FDR over the whole data.
    cat("METAData extracted. Doing FDR correction.\n")
    meta_pval_vec=unlist(meta_b_pval[[factOfIntName]])
    meta_pval_vec_adj=p.adjust(meta_pval_vec,method = "fdr")
    meta_pval_adj=matrix(meta_pval_vec_adj,nrow=NVertex,ncol=NROIS)
    #5.1.1 NEDA FDR correction. WORKS EXACTLY THE SAME AS p.adjust
    #    meta_pval_vec_thr=FDR(meta_pval_vec,0.01)
    #    meta_pval_adj_neda=((meta_pval<meta_pval_vec_thr)+0)*meta_pval
    #5.2 FDR by ROIs
    meta_pval_byROI_adj=matrix(0,NVertex,NROIS)
    for(y in 1:NROIS){
      meta_pval_vec_byROI=unlist(meta_b_pval[[factOfIntName]][,y])
      meta_pval_vec_byROI_adj=p.adjust(meta_pval_vec_byROI,method = "fdr")
      meta_pval_byROI_adj[,y]=matrix(meta_pval_vec_byROI_adj,nrow=NVertex,ncol=1,dimnames=list(NULL,c(paste("pval_",factOfIntName,sep=''))))      
    }
    cat("FDR correction done. Saving data\n")
    save(meta_d,meta_se,meta_zval,meta_pval,meta_ci.lb,meta_ci.ub,meta_tau2,meta_tause,meta_i2,meta_h2,meta_nctl,meta_npat,meta_pval_adj,meta_pval_byROI_adj,file=paste(resDir,'/',RUN_ID,'_meta_',cur_SM,'_',curModelName,'.RData',sep=''))
    write.csv(meta_pval_adj,file=paste(resDir,'/',RUN_ID,'_meta_pval_adj_',factOfIntName,'_',cur_SM,'_',curModelName,'.csv',sep=''))
    write.csv(meta_pval_adj,file=paste(resDir,'/',RUN_ID,'_meta_pval_adj_byROI_',CUR_ROI,'_',factOfIntName,'_',cur_SM,'_',curModelName,'.csv',sep=''))
    
    #this script is intended to be used with NNROIS=1 but I put here the 'if' statament just to be sure
    if (NROIS==1) {
	results_metaD_byROI<-cbind(meta_d[,1],meta_se[,1],meta_zval[,1],meta_pval[,1],meta_ci.lb[,1],meta_ci.ub[,1],meta_tau2[,1],meta_tause[,1],meta_i2[,1],meta_h2[,1],meta_nctl[,1],meta_npat[,1])
	colnames(results_metaD_byROI)<-c("meta_d","meta_se","meta_zval","meta_pval","meta_ci.lb","meta_ci.ub","meta_tau2","meta_tause","meta_i2","meta_h2","meta_nctl","meta_npat")
        write.csv(results_metaD_byROI,file=paste(resDir,'/',RUN_ID,'_meta_D_',CUR_ROI,'_',cur_SM,'_',curModelName,'.csv',sep=''))
    }

#    results_final<-rbind(meta_d,meta_se,meta_zval,meta_pval,meta_ci.lb,meta_ci.ub,meta_tau2,meta_tause,meta_i2,meta_h2,meta_nctl,meta_npat)
#    rownames(results_final)<-c("meta_d","meta_se","meta_zval","meta_pval","meta_ci.lb","meta_ci.ub","meta_tau2","meta_tause","meta_i2","meta_h2","meta_nctl","meta_npat")
#    write.csv(results_final,file=paste(resDir,'/',RUN_ID,'_meta_D_',cur_SM,'_',curModelName,'.csv',sep=''))

    if(analyze_betas==TRUE){
      meta_b_all<-matrix(unlist(meta_b),ncol=length(meta_b),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_",names(meta_b),sep='') ))
      meta_b_se_all<-matrix(unlist(meta_b_se),ncol=length(meta_b_se),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_se_",names(meta_b_se),sep='') ))
      meta_b_zval_all<-matrix(unlist(meta_b_zval),ncol=length(meta_b_zval),byrow=FALSE,dimnames=list(seq(1,NVertex),paste("meta_b_zval_",names(meta_b_zval),sep='') ))
      meta_b_pval_all<-matrix(unlist(meta_b_pval),ncol=length(meta_b_pval),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_pval_",names(meta_b_pval),sep='') ))
      meta_b_ci.lb_all<-matrix(unlist(meta_b_ci.lb),ncol=length(meta_b_ci.lb),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_ci.lb_",names(meta_b_ci.lb),sep='') ))
      meta_b_ci.ub_all<-matrix(unlist(meta_b_ci.ub),ncol=length(meta_b_ci.ub),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_ci.ub_",names(meta_b_ci.ub),sep='') ))
      meta_b_tau2_all<-matrix(unlist(meta_b_tau2),ncol=length(meta_b_tau2),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_tau2_",names(meta_b_tau2),sep='') ))
      meta_b_tause_all<-matrix(unlist(meta_b_tause),ncol=length(meta_b_tause),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_tause_",names(meta_b_tause),sep='') ))
      meta_b_i2_all<-matrix(unlist(meta_b_i2),ncol=length(meta_b_i2),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_i2_",names(meta_b_i2),sep='') ))
      meta_b_h2_all<-matrix(unlist(meta_b_h2),ncol=length(meta_b_h2),byrow=FALSE, dimnames=list(seq(1,NVertex),paste("meta_b_h2_",names(meta_b_h2),sep='') ))
      roi_column<-cbind(rep(CUR_ROI,NVertex))
      vertex_column<-cbind(seq(1,NVertex))
      colnames(roi_column)<-'ROI'
      colnames(vertex_column)<-'Vertex'
      save(meta_b_all, meta_b_se_all, meta_b_zval_all,meta_b_pval_all,meta_b_ci.lb_all,meta_b_ci.ub_all,meta_b_tau2_all,meta_b_tause_all,meta_b_i2_all,meta_b_h2_all, file=paste(resDir,'/',RUN_ID,'_meta_B_',cur_SM,'_',curModelName,'.RData',sep=''))
      results_b_final<-cbind(roi_column,vertex_column,meta_b_all,meta_b_se_all,meta_b_zval_all,meta_b_pval_all,meta_b_ci.lb_all,meta_b_ci.ub_all,meta_b_tau2_all,meta_b_tause_all,meta_b_i2_all,meta_b_h2_all)
      write.csv(results_b_final,file=paste(resDir,'/',RUN_ID,'_meta_B_',CUR_ROI,'_',cur_SM,'_',curModelName,'.csv',sep=''))
    }
        
    
    cat("Data saved.")
    }, warning = function(w) {
          cat(paste("WARNING: "), toString(w),sep='')
        }, error = function(e) {
          cat(paste("ERROR: ",toString(e),sep=''))
        }, finally = {
          
        })
  }
}

cat("METAANALYSIS SCRIPT FINISHED\n")
close(messages)
sink(file=NULL)
print("SCRIPT ENDED.")
