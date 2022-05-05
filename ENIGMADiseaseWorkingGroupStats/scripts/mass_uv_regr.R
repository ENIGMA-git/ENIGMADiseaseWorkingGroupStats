#----Main script for mass_uv_regr package. Don't change
#-Dmitry Isaev
#-Boris Gutman
#-Neda Jahanshad
# Beta version for testing on sites.
#-Imaging Genetics Center, Keck School of Medicine, University of Southern California
#-ENIGMA Project, 2015
# enigma@ini.usc.edu 
# http://enigma.ini.usc.edu
#-----------------------------------------------


#library(ppcor)
library(matrixStats)
# uncomment when moments library is installed..
library(moments)
#--0.
library(reticulate)
require(RCurl)
#library(googlesheets4, lib.loc = "/ifs/loni/faculty/thompson/four_d/amuir/condaenvs/envs/Rgooglesheets4/lib/R/library")
require(stringr)
paste0("finished loading packages")

#--1. READING THE COMMAND LINE---

cmdargs = commandArgs(trailingOnly=T)
ID=cmdargs[1]
RUN_ID=cmdargs[1]
paste0("finished first command")
# ID="UKBB_46K_APOE_AMM"
# RUN_ID="UKBB_46K_APOE_AMM"

SITE=cmdargs[2]
paste0("finished second command")
# SITE="UKBB46Kapoe"
SitePostfix<-SITE

DATADIR=cmdargs[3]
paste0("finished third command")
# DATADIR="/ifs/loni/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/RAW_SHAPE_4_TROUBLESHOOTING"

CURRENT_ROI=cmdargs[7]
paste0("finished fourth command")
# CURRENT_ROI="10"
RUN_ID=paste(ID,'_',CURRENT_ROI,sep='')

CURRENT_ROI_GSUB=gsub("-|/",".",CURRENT_ROI)
ROI<-eval(parse(text=paste('c("SubjID","',CURRENT_ROI_GSUB,'")',sep='')))

logDir=cmdargs[4]
paste0("finsihed fifth command")
# logDir="/ifs/loni/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/Vertex_Wise_Analyses/log"
LOG_FILE<-paste(logDir, '/',RUN_ID,'_',SITE,'.log',sep='')

resDir=cmdargs[5]
paste0("finsihed sixth command")
# resDir="/ifs/loni/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/Vertex_Wise_Analyses/res"
Results_CSV_Path<-paste(resDir,'/',RUN_ID,'_',sep='')

subjects_cov=cmdargs[6]
paste0("finsihed seventh command")
# subjects_cov="/ifs/loni/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/Vertex_Wise_Analyses/demographics_forAPOEcombo_10122020_APOEadded_subset.csv"
Subjects_Path<-subjects_cov

Config_Path=cmdargs[8] # google doc
paste0("finished eigth command")
# Config_Path="/ifs/loni/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/Vertex_Wise_Analyses/configure.csv"

ReadFromCsv_PrefixPath="metr_"
paste0("finished ninth command")

# KEVIN CHANGED: changed exclude path and read from csv prefix path to metr_
# i=9
Exclude_Path<-""
# ReadFromCsv_PrefixPath<-""
# while (i<=length(cmdargs)){
#   if(cmdargs[i]=="METR_PREFIX"){
#     i=i+1
#     ReadFromCsv_PrefixPath<-c(cmdargs[i])
#   }
#   if (cmdargs[i]=="-exclude_path"){
#     i=i+1
#     Exclude_Path<-cmdargs[i]   #Absolute path, BASH  
#   }
#   i=i+1
# }  

# not sure what QA level is
QA_LEVEL=1000
if ( (length(cmdargs)>8) & (cmdargs[8]!="-exclude_path") & (cmdargs[8]!="-shape_prefix")){
  QA_LEVEL<<-as.numeric(cmdargs[9])
}
QA_LEVEL <<- 2

#create log file
messages=file(LOG_FILE, open="wt")
#rest=file("rest.Rout", open="wt")
sink(messages, type="message")
sink(messages, type="output")

cat("1. LOG FILE CREATED\n")

# ~$ READING CONFIG CSV
# UYEN CHANGED: Sourcing to Python via r-reticulate to read config file from url

source_python("retrieve_gsheets.py")
pyConfigVars = r_to_py(c(ID, Config_Path))
config_currentRun = getSheetConfig(pyConfigVars)

# ~$ ERROR FOR >1 ID
if(nrow(config_currentRun)>1) {
  cat (paste("Error: number of rows with ID ",ID," is more than 1. Row must be unique.",sep=''))
  stop()
}

# $~ RETRIEVE ANALYSIS & DEMOG LIST PATH
AnalysisList_Path<-r_to_py(as.character(config_currentRun$AnalysisList_Path))
DemographicsList_Path<-r_to_py(as.character(config_currentRun$DemographicsList_Path))
# UYEN CHANGED: Conversion to py object, to read gsheet later via Python/Reticulate

# ~$ TYPE, TRAIT

cat(paste("Analysis list path: ",AnalysisList_Path,sep=''))
TYPE<-config_currentRun$Type
TRAIT_LIST<-config_currentRun$Trait
TRAIT_LIST<-gsub("[[:space:]]", "", TRAIT_LIST)
TRAIT_LIST<-gsub(";","\",\"",TRAIT_LIST)
METRICS<-eval(parse(text=paste('c("',TRAIT_LIST,'")',sep='')))

READ_FROM_CSV=(TYPE=='csv')

CSV_ROI_NAMES<-as.list(rep(NA,times=length(METRICS)))
names(CSV_ROI_NAMES)<-METRICS
for (elem in names(CSV_ROI_NAMES)) {
  CSV_ROI_NAMES[[elem]]<-ROI
}
RAW_EXT=".raw" 

setwd(DATADIR)
# /1. END OF READING THE COMMAND LINE

#--2. CONFIG FILE PARSING ROUTINES
str_extract_di<-function(strFilter1,strPattern){
  str_list=gregexpr(strPattern,strFilter1)[[1]]
  res<-c()
  for (i in 1:length(str_list)) {
    cur_elem=substr(strFilter1,str_list[i],str_list[i]+attr(str_list,"match.length")[i]-1)
    res<-c(res,cur_elem)
  }
  return (res)
}

get1FilterString<-function(strFilter1,strDataset){
  strForGSub=paste(strDataset,'$\\1',sep='')
  strCodeFilter1<-gsub("__(.*?)__",strForGSub,strFilter1) #removing "__" around variables

  arrStrArguments<-str_extract_di(strFilter1,"__(.*?)__")[[1]] #extracting all arguments to check for !=NA
  arrArgToCheck<-c()
  strForGSubIsNA=paste('(!is.na(',strDataset,'$',sep='') # seems like a problem?
  iArg=1

  for (arrName in arrStrArguments){
    arg<-substr(arrName,3,nchar(arrName)-2)
    arrArgToCheck[iArg]=paste(strForGSubIsNA,arg,'))',sep='')
    iArg=iArg+1
  }

  strNACheck<-paste(arrArgToCheck,collapse='&') #concatenating all arguments for !=NA
  strNACheck<-paste('(',strNACheck,')',sep='') # wrapping into brackets
  filter1String<-paste('((',strCodeFilter1,')&',strNACheck,')',sep='')
  return(filter1String)
}

# ALEX CHANGED: uncommented this since I have two filters (at least for the first analysis)
# KEVIN CHANGED: switched "is.na" to "is.null"
## Original version with two filters
getFullFilterString<-function(strFilterLeft,strFilterRight,strDataset){
  if (strFilterLeft != "" && (!is.null(strFilterLeft))){
    if(strFilterRight!= "" && (!is.null(strFilterRight)))
      return (paste('(',get1FilterString(strFilterLeft,strDataset),'|',get1FilterString(strFilterRight,strDataset),')',sep=''))
    else
      return (paste(get1FilterString(strFilterLeft,strDataset),sep=''))
  }
  else
    return("")
}

# ALEX CHANGED: commented this out since I have more than one filter (see note above) 
# edited version for one filter
#  getFullFilterString<-function(strFilterLeft,strDataset){
#    if (strFilterLeft!="" && (!is.na(strFilterLeft))){
#        return (paste(get1FilterString(strFilterLeft,strDataset),sep=''))
#    } else {
#      return("")
#    }
# }


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
    #print(paste("Couldn't find a factor for: ", coeffName,sep=''))
    print(paste("No main factor"))
    return(character(0))
  }
  return(factorName)
}

getLmText<-function(lmCoreText,siteRegr,covNames){
  SiteRegexp="Site[0-9]+"
  if(siteRegr=="all"){
    for(cname in covNames){
      siteRegressor=grep(SiteRegexp,cname,value=TRUE)
      if (length(siteRegressor)>0){
        lmCoreText<-paste(lmCoreText,'+',siteRegressor,sep='')
      }
      
    }
    return(lmCoreText)
  }
  else if(siteRegr==""){
    return(lmCoreText)
  }
  else {
    siteRegressors=paste(str_split(siteRegr,';')[[1]],collapse='+')
    lmCoreText<-paste(lmCoreText,'+',siteRegressors,sep='')
    return(lmCoreText)
  }
}
  
#--/2.END OF CONFIG FILE PARSING ROUTINES

#--3. FUNCTIONS USED IN THE CODE FOR COHEN's "d"

d.t.unpaired<-function(t.val,n1,n2){
  d<-t.val*sqrt((n1+n2)/(n1*n2))
  names(d)<-"effect size d"
  return(d)
}

partial.d<-function(t.val,df,n1,n2){
  d<-t.val*(n1+n2)/(sqrt(n1*n2)*sqrt(df))
  names(d)<-"effect size d"
  return(d)
}

CI1<-function(ES,se){
  ci<-c((ES-(1.96)*se),(ES+(1.96)*se))
  names(ci)<-c("95% CI lower","95% CI upper")
  return(ci)
}

se.d2<-function(d,n1,n2){
  se<-sqrt((n1+n2)/(n1*n2)+(d^2)/(2*(n1+n2-2)))
  names(se)<-"se for d"
  return(se)
}
#--/3. END OF FUNCTIONS USED IN THE CODE FOR COHEN's "d"

#--4. READ CONFIGURATION .CSV FILES. MIND SEPARATORS (';',',','.')

cat("4. READ CONFIGURATION .CSV FILES.\n")

dsSubjectsCov<-read.csv(Subjects_Path, header = TRUE)

#read file with exclusions 
if (Exclude_Path!=""){
  dsExcludeSubj<-read.csv(Exclude_Path, header = TRUE)
} else {
  dsExcludeSubj=NA
}
#read linear models analysis list
# cat(AnalysisList_Path)
# cat("\n")
# cat(DemographicsList_Path)
#read analysis, demographics configuration file

# UYEN CHANGED: uses external Python function to read gsheet
dsAnalysisConf<-openSaveGSheet(AnalysisList_Path)
dsDemographicsConf<-openSaveGSheet(DemographicsList_Path)
##--/4. END OF READING CONFIGURATION .CSV FILES.
cat("4. END OF READING CONFIGURATION .CSV FILES.\n")

#--5. PROCESS DEMOGRAPHICS FOR COVARIATES ('COV" section of config file)
cat("5. PROCESS DEMOGRAPHICS FOR COVARIATES ('COV' section of config file)\n")

#get covariate metrics for demographics.
dsDemogCOV=dsDemographicsConf[which(dsDemographicsConf$Type=="COV"),]    
strAllCov<-list()
for (iCOV in 1:nrow(dsDemogCOV)){
  if (dsDemogCOV$Active[iCOV]==0) next
  var=paste(dsDemogCOV$Type[iCOV],'_',dsDemogCOV$varname[iCOV],sep='')
  if (dsDemogCOV$Filter[iCOV]=="None"){
    eval(parse(text=paste(var,'=1:nrow(dsSubjectsCov)',sep=''))) #if there's no filter, select all
  }
  else{
    eval(parse(text=paste(var,'=','which',get1FilterString(dsDemogCOV$Filter[iCOV],'dsSubjectsCov'),sep='')))
  }

  stFunc=strsplit(dsDemogCOV$Stats[iCOV],';')[[1]]
  stVars=strsplit(dsDemogCOV$StatsNames[iCOV],';')[[1]]
  stVarToSave<-c(length(stVars))
  if (length(stFunc)!=length(stVars)){
    cat ("For variable: ", dsDemogCOV$varname[iCOV], "length of Statistics functions and Statistics variable names is not equal! Proceeding with the next variable\n")
    next
  }
  for(iCur in 1:length(stVars)){
    postfix=ifelse(((dsDemogCOV$Postfix[iCOV]=="")|(is.na(dsDemogCOV$Postfix[iCOV]))),"",paste('.',dsDemogCOV$Postfix[iCOV],sep=''))
#    a1=paste(var,'.',stVars[iCur],postfix,'=',stFunc[iCur],'(dsSubjectsCov$',dsDemogCOV$Covariate[iCOV],'[',var,']',',na.rm=TRUE)\n',sep='')
    eval(parse(text=paste(var,'.',stVars[iCur],postfix,'=',stFunc[iCur],'(dsSubjectsCov$',dsDemogCOV$Covariate[iCOV],'[',var,']',',na.rm=TRUE)\n',sep='')))
    stVarToSave[iCur]=paste(var,'.',stVars[iCur],postfix,sep='')
  }
  strForSave=paste(stVarToSave,collapse=',')
  if(dsDemogCOV$SepFile[iCOV]==1){
#    strForSave=paste(stVarToSave,collapse=',')
	cat("Using sepfile=1 for COV section is deprecated\n")    
#	cat(paste('save(',strForSave,',CURRENT_ROI,','file=\'',dsDemogCOV$Type[iCOV],'_',dsDemogCOV$varname[iCOV],'.RData\')',sep=''))
#    eval(parse(text=paste('save(',strForSave,',CURRENT_ROI,','file=\'',dsDemogCOV$Type[iCOV],'_',dsDemogCOV$varname[iCOV],'.RData\')',sep='')))
  }
  strAllCov<-c(strAllCov,strForSave)
  
}
#save all covariates into 1 file
strAllCovToSave=paste(strAllCov,collapse=',')
eval(parse(text=paste('save(',strAllCovToSave,',file=\'',Results_CSV_Path,'COVARIATES.RData\')',sep='')))
#--/5.END OF PROCESSING DEMOGRAPHICS FOR COVARIATES
cat("5.END OF PROCESSING DEMOGRAPHICS FOR COVARIATES\n")

#--6. PROCESSING DEMOGRAPHICS - NUMBER OF ELEMENTS FOR COVARIATES (Section 'NUM' in config file)

cat("6. PROCESSING DEMOGRAPHICS - NUMBER OF ELEMENTS FOR COVARIATES (Section 'NUM' in config file)\n")
dsDemogNUM=dsDemographicsConf[which(dsDemographicsConf$Type=="NUM"),]    
strAllCov<-list()
for (iNUM in 1:nrow(dsDemogNUM)){
  var=paste(dsDemogNUM$Type,'_',dsDemogNUM$varname[iNUM],sep='')
  if (dsDemogNUM$Filter[iNUM]==""){
    eval(parse(text=paste(var,'=1:nrow(dsSubjectsCov)',sep=''))) #if there's no filter, select all
  }
  else{
    eval(parse(text=paste(var,'=','which',get1FilterString(dsDemogNUM$Filter[iNUM],'dsSubjectsCov'),sep='')))
  }
  
  stFunc=strsplit(dsDemogNUM$Stats[iNUM],';')[[1]]
  stVars=strsplit(dsDemogNUM$StatsNames[iNUM],';')[[1]]
  stVarToSave<-c(length(stVars))
  if (length(stFunc)!=length(stVars)){
    cat ("For variable: ", dsDemogNUM$varname[iNUM], "length of Statistics functions and Statistics variable names is not equal! Proceeding with the next variable\n")
    next
  }
  for(iCur in 1:length(stVars)){
    #        cat(paste(var,'.',stVars[iCur],'=',stFunc[iCur],'(dsMetrics[',var,',(ncol(dsSubjectsCov)+1):ncol(dsMetrics)],na.rm=TRUE)',sep=''))
    eval(parse(text=paste(var,'.',stVars[iCur],'=',stFunc[iCur],'(',var,')',sep='')))
    stVarToSave[iCur]=paste(var,'.',stVars[iCur],sep='')
  }
  strForSave=paste(stVarToSave,collapse=',')
  if(dsDemogNUM$SepFile[iNUM]==1){
     cat("Using sepfile=1 for NUM section is deprecated\n")    

#    strForSave=paste(stVarToSave,collapse=',')
#    eval(parse(text=paste('save(',strForSave,',cur_roi,','file=\'',dsDemogNUM$Type[iNUM],'_',dsDemogNUM$varname[iNUM],'_',toString(cur_roi),'.RData\')',sep='')))
  }
  strAllCov<-c(strAllCov,strForSave)
}
#save all covariates into 1 file
strAllCovToSave=paste(strAllCov,collapse=',')
eval(parse(text=paste('save(',strAllCovToSave,',file=\'',Results_CSV_Path,'NUM.RData\')',sep='')))
#--6.END OF PROCESSING DEMOGRAPHICS - NUMBER OF ELEMENTS FOR COVARIATES 
cat("6.END OF PROCESSING DEMOGRAPHICS - NUMBER OF ELEMENTS FOR COVARIATES\n")

#--7. MAIN CYCLE STARTS. PROCESSING  METRICS
cat("7. MAIN CYCLE STARTS. PROCESSING METRICS\n")
for (cur_sm in METRICS){    #for each metric
  cat(paste("Reading Metrics: ", cur_sm,'\n',sep=''))
  
  if(READ_FROM_CSV) {
    #!!! mind the settings for reading csv (sep='.',dec=',')      
    csvMetricsFile<-paste(ReadFromCsv_PrefixPath,cur_sm,'.csv',sep='')
    csvMetrics<-read.csv(csvMetricsFile)
    cortcolind<-match(CSV_ROI_NAMES[[cur_sm]],names(csvMetrics)) #control if .csv headers match our settings    
    if(length(which(is.na(cortcolind))) > 0){
      cat (paste(toString(names(csvMetrics)), "\n",sep=''))
      cat(paste (toString(cortcolind),"\n",sep=''))
      cat("CSV ROI Names:\n")
      print(CSV_ROI_NAMES)
      stop('At least one of the required columns in your ', csvMetricsFile, ' file is missing. Make sure that the column names are spelled exactly as listed in the protocol\n')
      
    }
  }
  
  #first process demographics data
  # ?Should we process this data for each ROI, keeping in mind excluded subjects. 
  # Now we work on the whole unfiltered bunch of covariates data
  
  
  #--7.1 READING DATA FOR EACH ROI INTO LIST & PROCESSING DEMOGRAPHICS FOR METRICS 
  #get Metrics for demographics
  dsDemogSM=dsDemographicsConf[which(dsDemographicsConf$Type=="METRICS"),]    
  
  dsMetricsList=list()
  for (cur_roi in ROI) {
    
    #Read subjects to exlude for current ROI//
    if(Exclude_Path!="") {
      #        excludedSubjectsRoi<-eval(parse(text=paste("dsExcludeSubj$R",toString(cur_roi),sep='')))
      excludedSubjectsRoi<-eval(parse(text=paste("as.vector(dsExcludeSubj$SubjID[as.vector(dsExcludeSubj$ROI",toString(cur_roi),"<",toString(QA_LEVEL),")])",sep='')))
      cat(paste("QA Level=",QA_LEVEL,sep=''))
    }
    else {
      excludedSubjectsRoi=c()
    }
    
    print (paste("Excluded subjects for ROI ",toString(cur_roi),": ",toString(excludedSubjectsRoi),sep=''))
    
    #Filter out excluded Subjects
    if (length(excludedSubjectsRoi)>0) {
      dsSubjectsCovToRead<-subset(dsSubjectsCov,!SubjID %in% excludedSubjectsRoi)
    }
    else {
      dsSubjectsCovToRead<-dsSubjectsCov
    }
    #      print (paste("Included subjects for ROI", toString(cur_roi),": ",toString(dsSubjectsCovToRead$SubjID),sep=''))
    
    # ALEX ADDED: THIS SECTION IS COMMENTED OUT BECAUSE WE ALREADY HAVE THE DATA SAVED...for troubleshooting
    #-- 7.1.1 READ DATA FOR ROI
    
    cat(paste("7.1.1 READ DATA FOR ROI: ",toString(cur_roi),'\n',sep=''))
    matr_created=FALSE
    if (cur_roi=="SubjID") next
    if(READ_FROM_CSV==TRUE){
      dsMetrics=eval(parse(text=paste('data.frame(csvMetrics$SubjID,csvMetrics$',cur_roi,')',sep='')))
      colnames(dsMetrics)=c("SubjID","V1")
    }
    else {
      #progress bar
      pbReadSubjects <- txtProgressBar(1,length(dsSubjectsCovToRead$SubjID),title='Reading subjects.')
      iPb=1  #counter for progress bar
      nnn=1
      subjList=dsSubjectsCovToRead$SubjID
      for (cur_subject in subjList) { #for each subject
        f_toRead <- file(paste(DATADIR,"/",cur_subject,"/",cur_sm,"_",cur_roi,RAW_EXT,sep=""),"rb")
        curSubjectData<-readBin(f_toRead, numeric(), n= 999999, size=4)
        close(f_toRead)

        if (length(curSubjectData)==0) {
          cat(paste("NULL bytes in data for ROI ",cur_roi," : Subject ", cur_subject,'\n',sep=''))
          dsSubjectsCovToRead<-subset(dsSubjectsCovToRead,!SubjID %in% cur_subject)
          next
        }
        # cat(paste(toString(iPb),':',cur_subject,' : ',DATA_PATH,cur_subject,"/",DATADIR,"/",cur_sm,"_",cur_roi,RAW_EXT,'\n',sep=""))

        if(!matr_created){
          matr<-curSubjectData
          matr_created=TRUE
          cat("matr_created.\n")
        }
        else{
          matr<-rbind(matr,curSubjectData,deparse.level = 0)
        }
        setTxtProgressBar(pbReadSubjects,iPb)
        iPb=iPb+1

      }
      close(pbReadSubjects)
      dsMetrics=as.data.frame(matr, stringsAsFactors=FALSE)
      dsMetrics<-data.frame(dsSubjectsCovToRead$SubjID, dsMetrics)
      colnames(dsMetrics)[1]<-"SubjID"
    }
    dsMetrics=merge(dsSubjectsCovToRead,dsMetrics,by='SubjID')
    if(nrow(dsMetrics)!=nrow(dsSubjectsCovToRead)){
      cat(paste("Metrics Subjects and Covariates Subjects DO NOT MATCH for ROI: ", cur_roi,'\n', sep=''))
      dsMetrics=NA
      dsMetricsList[[toString(cur_roi)]]=dsMetrics
      next
    }
    dsMetricsList[[toString(cur_roi)]]=dsMetrics

# ALEX ADDED: want to save out the matr dataframe and the dsMetrics to see if I can save time
# save(matr, file = "/ifs/loni/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/Vertex_Wise_Analyses/matr.Rdata")
# save(dsMetrics, file = "/ifs/loni/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/Vertex_Wise_Analyses/dsMetrics.Rdata")
# load("/Volumes/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/Vertex_Wise_Analyses/matr.Rdata")
# load("/Volumes/faculty/thompson/four_d/amuir/UKBB/UKBB_SHAPE/Vertex_Wise_Analyses/dsMetrics.Rdata")

    #--/7.1.1 END OF READING DATA FOR ROI
    cat(paste("/7.1.1 END OF READING DATA FOR ROI: ",toString(cur_roi),'\n',sep=''))
    #--7.1.2 PROCESS DEMOGRAPHICS FOR ROI
    cat(paste("7.1.2 PROCESS DEMOGRAPHICS FOR ROI: ",toString(cur_roi),'\n',sep=''))
    strAllSM<-""
    for (iSM in 1:nrow(dsDemogSM)){
      if(dsDemogSM$Active[iSM]!=1){
        next
      }
      
      
      var=paste(dsDemogSM$Type,'_',dsDemogSM$varname[iSM],sep='')
      if (dsDemogSM$Filter[iSM]=="None"){
        eval(parse(text=paste(var,'=1:nrow(dsMetrics)',sep=''))) #if there's no filter, select all
      }
      else{
        eval(parse(text=paste(var,'=','which',get1FilterString(dsDemogSM$Filter[iSM],'dsMetrics'),sep='')))
      }
      
      
      stFunc=strsplit(dsDemogSM$Stats[iSM],';')[[1]]
      stVars=strsplit(dsDemogSM$StatsNames[iSM],';')[[1]]
      stVarToSave<-c(length(stVars))
      if (length(stFunc)!=length(stVars)){
        cat ("For variable: ", dsDemogSM$varname[iSM], "length of Statistics functions and Statistics variable names is not equal! Proceeding with the next variable\n")
        next
      }
      
      for(iCur in 1:length(stVars)){
        #        cat(paste(var,'.',stVars[iCur],'=',stFunc[iCur],'(dsMetrics[',var,',(ncol(dsSubjectsCov)+1):ncol(dsMetrics)],na.rm=TRUE)',sep=''))
        if(stFunc[iCur]=="lengthNNA") {
          eval(parse(text=paste(var,'.',stVars[iCur],'=','colSums(!is.na','(data.matrix(dsMetrics[',var,',(ncol(dsSubjectsCov)+1):ncol(dsMetrics)])',')',',na.rm=TRUE)',sep='')))
        }
        else if (stFunc[iCur]=="kurtosis"){
          if(READ_FROM_CSV!=TRUE){
            cat("KURTOSIS is only applicable to csv data")
            next              
          }
          
          # Comment out next 3 lines when 'moments' library is installed.
          #cat ("'moments' library is not installed. Skipping kurtosis computation.\n")
          #stVarToSave[iCur]=NA
          #next
          
          #Uncomment next line when 'moments' library is installed.
          eval(parse(text=paste(var,'.',stVars[iCur],'=','kurtosis(dsMetrics$V1[!is.na(dsMetrics$V1)])',sep='')))  
          
        }
        else if (stFunc[iCur]=="skewness"){
          if(READ_FROM_CSV!=TRUE){
            cat("SKEWNESS is only applicable to csv data")
            next              
          }
          # Comment out next 3 lines when 'moments' library is installed.
          #cat ("'moments' library is not installed. Skipping skewness computation.\n")
          #stVarToSave[iCur]=NA
          #next
          
          #Uncomment next line when 'moments' library is installed.
          eval(parse(text=paste(var,'.',stVars[iCur],'=','skewness(dsMetrics$V1[!is.na(dsMetrics$V1)])',sep='')))              
        }
        else {
          eval(parse(text=paste(var,'.',stVars[iCur],'=',stFunc[iCur],'(data.matrix(dsMetrics[',var,',(ncol(dsSubjectsCov)+1):ncol(dsMetrics)]),na.rm=TRUE)',sep='')))
        }
        stVarToSave[iCur]=paste(var,'.',stVars[iCur],sep='')
      }
      stVarToSave=stVarToSave[!is.na(stVarToSave)]
      strForSave= if (length(stVarToSave)==0) "" else paste(stVarToSave,collapse=',')
      
      if(dsDemogSM$SepFile[iSM]==1){
        cat("saving metrics to a separate file is deprecated in current version.\n")
        #          strForSave=paste(stVarToSave,collapse=',')
      }
      strAllSM<-if (strForSave!="") paste(strForSave,strAllSM,sep=',') else strAllSM
    }
    eval(parse(text=paste('save(',strAllSM,'cur_roi,cur_sm,','file=\'',Results_CSV_Path,dsDemogSM$Type[iSM],'_',cur_sm,'_',toString(cur_roi),'.RData\')',sep='')))
    
    #--/7.1.2 END OF PROCESSING DEMOGRAPHICS FOR ROI
    cat(paste("/7.1.2 END OF PROCESSING DEMOGRAPHICS FOR ROI: ",toString(cur_roi),'\n',sep=''))
  }
  
  
  #-- 7.2 PROCESSING LINEAR MODELS --
  cat("7.2 PROCESSING LINEAR MODELS\n")
  for (cur_rowAnalysis in 1:nrow(dsAnalysisConf)){
    resMatr_created=FALSE
    
    #Read Analysis parameters
    if (dsAnalysisConf$Active[cur_rowAnalysis]==0) {next}
    cat(paste("Processing model: ",dsAnalysisConf$ID[cur_rowAnalysis],":",dsAnalysisConf$Name[cur_rowAnalysis],'\n',sep=''))
    strCovariates<-dsAnalysisConf$NewRegressors[cur_rowAnalysis]
    strFilter1<-dsAnalysisConf$Filter[cur_rowAnalysis]
    strFilter2<-dsAnalysisConf$Filter2[cur_rowAnalysis]
    
    ## SUBJID REMOVED FROM MODEL HERE
    #di_debug
    print(colnames(dsSubjectsCov))
    lmText<-getLmText(dsAnalysisConf$LM[cur_rowAnalysis],dsAnalysisConf$SiteRegressors,colnames(dsSubjectsCov)) 
    lmText<-getLmText(dsAnalysisConf$LM[cur_rowAnalysis],colnames(dsSubjectsCov)) 
    #lmText <- gsub('[+]Site1', '', lmText) # Drop site as a predictor
    lmText_nosub <- gsub('[+]SubjID', '', lmText)  # Drop SubjID from model
    cat(lmText_nosub,'\n')
    #lmvars<-strsplit(lmText,'\\+')[[1]]
    lmvars<-strsplit(lmText_nosub,'\\+')[[1]]
    lmvars<-gsub(" ","",lmvars)
    
    lmvars_plain<-c()      
    for (elem in lmvars) {
      if (length(grep(".*:.*",elem))>0) {
        elemlist<-strsplit(elem,'\\:')[[1]]
        
        lmvars_plain<-c(lmvars_plain,elemlist)
      }
      else {
        lmvars_plain<-c(lmvars_plain,elem)
      }		
    }
    lmvars_plain<-mapply(gsub,"factor\\(","",lmvars_plain)
    lmvars_plain<-mapply(gsub,"\\(","",lmvars_plain)
    lmvars_plain<-mapply(gsub,"\\)","",lmvars_plain)
    
    lmvars_plain<-unique(lmvars_plain)
    
    lmMainFactor<-dsAnalysisConf$MainFactor[cur_rowAnalysis]
    factorOfInterest<-dsAnalysisConf$FactorOfInterest[cur_rowAnalysis]
    error_occured=0     
    
    #-- 7.2.1 Applying LM to each ROI
    for (cur_roi in ROI){           
      if(cur_roi=="SubjID") next
      print(paste("Reading ROI ",cur_roi,sep=''))
      
      
      ##Read subjects to exlude for current ROI//
      #if(!is.na(dsExcludeSubj)) excludedSubjectsRoi<-eval(parse(text=paste("as.vector(dsExcludeSubj$SubjID[as.vector(dsExcludeSubj$ROI",toString(cur_roi),"<",toString(QA_LEVEL),")])",sep=''))) #excludedSubjectsRoi<-eval(parse(text=paste("dsExcludeSubj$R",toString(cur_roi),sep='')))
      #else excludedSubjectsRoi=c()
      #print (paste("Excluded subjects for ROI",toString(cur_roi),": ",toString(excludedSubjectsRoi),sep=''))
      
      dsMetrics=dsMetricsList[[toString(cur_roi)]]
      
      if(is.na(dsMetrics)) {
        cat(paste("dsMetrics for ROI: ", cur_roi, " has 0 rows. Skipping it.\n",sep=''))
        next
      }
      #Filter out excluded Subjects
      if (length(excludedSubjectsRoi)>0) {
        dsMetricsFiltered<-subset(dsMetrics,!SubjID %in% excludedSubjectsRoi)
      }
      else {
        dsMetricsFiltered<-dsMetrics
      }
      lmvars_plain<-intersect(lmvars_plain,colnames(dsMetricsFiltered))
      dsMetricsFiltered<-dsMetricsFiltered[complete.cases(dsMetricsFiltered[,lmvars_plain]),]
      nCovariates=ncol(dsSubjectsCov)
      #Additional covariates
      if(strCovariates!=""&& !(is.na(strCovariates))){
        arrCovSplitted<-strsplit(strCovariates,';')[[1]]
        #arrCovText<-gsub("__(.*?)__","dsMetricsFiltered$\\1",arrCovSplitted)
        arrCovText<-gsub("__(.*?)__","dsMetricsFiltered\\1",arrCovSplitted)
        for (cur_covText in arrCovText){
          
          eval(parse(text=cur_covText))
          #put the new column into the beginning
          cNames<-colnames(dsMetricsFiltered)
          cNamesNew<-c(cNames[length(cNames)],cNames[1:length(cNames)-1])
          dsMetricsFiltered<-dsMetricsFiltered[cNamesNew]
          nCovariates=nCovariates+1
        }
      }
     
      #Apply Filters from LM
      # fs<-getFullFilterString(strFilter1,'dsMetricsFiltered') # ALEX CHANGED: added in the second filter
      fs<- getFullFilterString(strFilter1, strFilter2, 'dsMetricsFiltered')
      if (fs!="") {
        dsMetricsFiltered_CurrentLM<-eval(parse(text=paste('dsMetricsFiltered[',fs,',]',sep='')))
      } else {
        dsMetricsFiltered_CurrentLM<-dsMetricsFiltered
      }
      
      #allocate empty vectors to store adjust effect sizes, se, ci (noicv)
      r.cort=rep(NA,ncol(dsMetrics)-1)
      d.cort=rep(NA,ncol(dsMetrics)-1)
      se.cort=rep(NA,ncol(dsMetrics)-1)
      low.ci.cort=rep(NA,ncol(dsMetrics)-1)
      up.ci.cort=rep(NA,ncol(dsMetrics)-1)
      n.controls=rep(NA,ncol(dsMetrics)-1)
      n.patients=rep(NA,ncol(dsMetrics)-1)
      n.overall=rep(NA,ncol(dsMetrics)-1)
      pval=rep(NA,ncol(dsMetrics)-1)
      pvalOfInt=rep(NA,ncol(dsMetrics)-1)
      std=rep(NA,ncol(dsMetrics)-1)
      # ** by now, all the filters are applied to the data, the text of LM is prepared, and we are ready to run LM on each vertex
      
      attach(dsMetricsFiltered_CurrentLM)
      
      #loop over vertices and create linear model for each vertex
      cat("Computing Linear Model for the current ROI...")
      
      pbLinModels <- txtProgressBar(1,ncol(dsMetricsFiltered_CurrentLM),title='Reading subjects.')
      iPb=1 #counter for progress bar
      lmList<-c()      
      result = tryCatch({
        
        # **APPLYING LM TO EACH VERTEX // ncol(dsSubjectsCov)//
        for (cur_vert in (nCovariates+1):ncol(dsMetricsFiltered_CurrentLM)) { #beginning from 1st metrics column
          #cur_vertInd=cur_vert-ncol(dsSubjectsCov)
          cur_vertInd=cur_vert-nCovariates
          res<-dsMetricsFiltered_CurrentLM[,cur_vert]
          #lmFullText<-paste('lmfit<-lm(res','~',lmText,')',sep='')
          lmFullText<-paste('lmfit<-lm(res','~',lmText_nosub,')',sep='')
          eval(parse(text=lmFullText))
          
          if (dsAnalysisConf$SaveLM[cur_rowAnalysis]==1){
            lmList[[cur_vert-nCovariates]]<-lmfit
            lmList[[cur_vert-nCovariates]]$model=NA
          }
          metaData=c(cur_sm,cur_roi,cur_vertInd)  # -1 because vertexes start from 2nd column
          names(metaData)=c("Metrics","ROI","Vertex")
          tmp=summary(lmfit)
          stes=tmp$coefficients[,2]
          coeffs=tmp$coefficients[,1]
          #	    coeffs=coefficients(lmfit)
          for (i in 1:length(names(coeffs))){
            names(stes)[i]<-paste('st_err_',names(coeffs)[i],sep='')
            names(coeffs)[i]<-paste('beta_',names(coeffs)[i],sep='')
            
            # **LM is applied now time for Effect size data processing
          }
          contvalue=ifelse(!is.na(dsAnalysisConf$ContValue[cur_rowAnalysis])&dsAnalysisConf$ContValue[cur_rowAnalysis]!="",dsAnalysisConf$ContValue[cur_rowAnalysis],0)
          patvalue=ifelse(!is.na(dsAnalysisConf$PatValue[cur_rowAnalysis])&dsAnalysisConf$PatValue[cur_rowAnalysis]!="",dsAnalysisConf$PatValue[cur_rowAnalysis],1)
          
          contmin=ifelse(!is.na(dsAnalysisConf$ContMin[cur_rowAnalysis])&dsAnalysisConf$ContMin[cur_rowAnalysis]!="",dsAnalysisConf$ContMin[cur_rowAnalysis],0)
          patmin=ifelse(!is.na(dsAnalysisConf$PatMin[cur_rowAnalysis])&dsAnalysisConf$PatMin[cur_rowAnalysis]!="",dsAnalysisConf$PatMin[cur_rowAnalysis],1)
          
          
          n.controls[cur_vertInd] = length(which(lmfit$model[,2] == contvalue))
          n.patients[cur_vertInd] = length(which(lmfit$model[,2] == patvalue))
          n.overall[cur_vertInd]= nrow(lmfit$model)
          
          #Convert the lm model to a summary format so we can extract statistics
          
          # ALEX: this was commented out in the original script, but I think this may be why I am getting a Cohen's d that is NA
          # so I am going to comment it back in and see what happens.
          tstat=tmp$coefficients[2,3] # Get t-statistic from regression to convert to Cohens d
          factorName=getTstatFactorName(lmMainFactor,rownames(tmp$coefficients))
          factorOfIntName<-getTstatFactorName(factorOfInterest,rownames(tmp$coefficients))
          tstat=tmp$coefficients[factorName,3]
          
          tstat.df=tmp$df[2]
          pvalname=''
          #if lmMainFactor contains word "factor" => do a T-Test. Else - do Partial Correlations
          
          pvalOfInt[cur_vertInd]<-tmp$coefficients[factorOfIntName,4]            
          pvalOfIntName<-paste('p.val.OfInt_',factorOfIntName,sep='')
          if (length(grep("factor",lmMainFactor,value=TRUE))==0) {
            # this is the part for continuous variables.
            if(lmMainFactor!="" | is.na(lmMainFactor)){
              #cat("Partial correlations\n")
              
              pcorvars <- grep('SubjID', colnames(lmfit$model), value = T, invert = T)
              pcordat <- data.frame(sapply(pcorvars, function(x){
                as.numeric(lmfit$model[[x]])
              }))
              
              partcor.i <- pcor.test(x=pcordat[, 1], y=pcordat[, 2], z=pcordat[, 3:ncol(pcordat)])
              
              #partcor.i <- pcor.test(lmfit$model[1],lmfit$model[,2],lmfit$model[,c(3:ncol(lmfit$model))])	
              r.cort[cur_vertInd]=partcor.i[,1]
              pval[cur_vertInd]=partcor.i[,2]   #mind that here pval is not for the beta, but for partial correlations
              se.cort[cur_vertInd]=tmp$coefficients[factorOfIntName,2]  #here se is not derived from Cohen's d, but directly taken from the linear model
              pvalname='p.val_corr'
            }
            else {
              pval[cur_vertInd]=NA
              pvalname='p.val'
              
            }
          }
          else {
            pvalname=paste('p.val_',factorName,sep='')
            #this is the part for factors with levels
            #collect effect size data
            if((n.controls[cur_vertInd]<contmin)|(n.patients[cur_vertInd]<patmin))
            {		
              #this happens when you don't have enough patients and conrols
              d.cort[cur_vertInd]=NA
              se.cort[cur_vertInd]=NA
              bound.cort=NA
              low.ci.cort[cur_vertInd]=NA
              up.ci.cort[cur_vertInd]=NA
              pval[cur_vertInd]=NA
              std[cur_vertInd]=NA
            }
            else {
              #		cat ("FACTOR NAME: \n")
              #		cat(factorName)
              #		cat ("lm Main Factor: \n")
              #		cat(lmMainFactor)
              if (length(grep(".*:.*",factorName))>0){	# interaction means no Cohen's D
                d.cort[cur_vertInd]=NA
                se.cort[cur_vertInd]=NA
                bound.cort=NA
                low.ci.cort[cur_vertInd]=NA
                up.ci.cort[cur_vertInd]=NA
                pval[cur_vertInd]=tmp$coefficients[factorName,4] #pval is directly taken from linear model                	
              }
              else if (length(unique(lmfit$model[lmMainFactor]))>2) { #if factor level amount is greater than 2 that also means no Cohen's D
                d.cort[cur_vertInd]=NA
                se.cort[cur_vertInd]=NA
                bound.cort=NA
                low.ci.cort[cur_vertInd]=NA
                up.ci.cort[cur_vertInd]=NA
                pval[cur_vertInd]=tmp$coefficients[factorName,4] #pval is directly taken from linear model                	
              }
              else {	
                #this is when you have enough patients and controls - computing cohen's d and standard error
                d.cort[cur_vertInd]=partial.d(tstat,tstat.df,n.controls[cur_vertInd],n.patients[cur_vertInd])
                se.cort[cur_vertInd]=se.d2(d.cort[cur_vertInd],n.controls[cur_vertInd],n.patients[cur_vertInd])
                bound.cort=CI1(d.cort[cur_vertInd],se.cort[cur_vertInd])
                low.ci.cort[cur_vertInd]=bound.cort[1]
                up.ci.cort[cur_vertInd]=bound.cort[2]
                pval[cur_vertInd]=tmp$coefficients[factorName,4] #pval is directly taken from linear model                
              }              
            }              
          }
          
          
          #create matrix for the effect size for each vertex
          effectSize=c(pvalOfInt[cur_vertInd],r.cort[cur_vertInd],d.cort[cur_vertInd],se.cort[cur_vertInd],low.ci.cort[cur_vertInd],up.ci.cort[cur_vertInd],n.controls[cur_vertInd],n.patients[cur_vertInd],n.overall[cur_vertInd],pval[cur_vertInd])
          
          names(effectSize)<-c(pvalOfIntName,paste('r_',cur_sm,'_vs_',factorName,sep=''),paste('d_',factorName,sep=''),paste('st_err(d)_',factorName,sep=''),paste('low.ci(d)_',factorName,sep=''),paste('up.ci(d)_',factorName,sep=''),'n.controls','n.patients','n.overall',pvalname)
          
          
          resRow<-c(metaData,coeffs,stes,effectSize)
          if(!resMatr_created){
            resMatr<-matrix(resRow,nrow=1,ncol=length(resRow),dimnames=list(c(),names(resRow)))
            resMatr_created=TRUE
          } 
          else{
            resMatr<-rbind(resMatr,resRow,deparse.level = 0)
          }
          setTxtProgressBar(pbLinModels,iPb)
          iPb=iPb+1
        }
        error_occured<<-0
      }, warning = function(w) {
        cat(paste("WARNING: "), toString(w),sep='')
      }, error = function(e) {
        cat(paste("ERROR: ",toString(e),sep=''))
        error_occured<<-1
        
      }, finally = {
        
      })
      
      cat ("...Done computing Linear Model for the current ROI\n")
      detach(dsMetricsFiltered_CurrentLM)
      
    }
    cat(paste("error_occ:",as.character(error_occured),sep=''))
    if(error_occured==0) {   
      #-- /7.2.1 END OF Applying LM to each ROI
      write.csv(resMatr,file=paste(Results_CSV_Path,cur_sm,'_',dsAnalysisConf$ID[cur_rowAnalysis],"_",SitePostfix,".csv",sep=''),row.names=FALSE)
      if (dsAnalysisConf$SaveLM[cur_rowAnalysis]==1){
        save(lmList,file=paste(Results_CSV_Path,cur_sm,'_LM_',dsAnalysisConf$ID[cur_rowAnalysis],"_",SitePostfix,'.Rdata',sep=''))
      }
    }
    cat(paste("End of processing model: ",dsAnalysisConf$ID[cur_rowAnalysis],":",dsAnalysisConf$Name[cur_rowAnalysis],'\n',sep=''))
    
    close(pbLinModels)
  }
  #--/7.2 END OF PROCESSING LMs
}

#--/7.END OF MAIN CYCLE
print("The ENIGMA regression script has completed!.")
close(messages)
sink(file=NULL)

