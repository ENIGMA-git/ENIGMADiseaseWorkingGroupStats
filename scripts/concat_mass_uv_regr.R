#----Postprocessing script for mass_uv_regr package. Don't change
#-Dmitry Isaev
#-Boris Gutman
#-Neda Jahanshad
# Beta version for testing on sites.
#-Imaging Genetics Center, Keck School of Medicine, University of Southern California
#-ENIGMA Project, 2015
# enigma@ini.usc.edu 
# http://enigma.ini.usc.edu
#-----------------------------------------------



library(ppcor)
library(matrixStats)
library(reticulate)
#--0.
require(RCurl)

# read_web_csv<-function(url_address){
#   gdoc3=paste(url_address,'/export?format=csv&id=KEY',sep='')
#   myCsv <- getURL(gdoc3,.opts=list(ssl.verifypeer=FALSE))
#   csv_res<-read.csv(textConnection(myCsv),header = TRUE,stringsAsFactors = FALSE)
#   return (csv_res)
# }

#grabbed from stackOverflow - function for binding two datasets with non-equal list of columns
rbind.ordered=function(x,y){

  if (is.null(x)) return(y)

  if (is.null(y)) return(x)

  diffCol = setdiff(colnames(x),colnames(y))
  if (length(diffCol)>0){
    cols=colnames(y)
    for (i in 1:length(diffCol)) y=cbind(y,NA)
    colnames(y)=c(cols,diffCol)
  }

  diffCol = setdiff(colnames(y),colnames(x))
  if (length(diffCol)>0){
    cols=colnames(x)
    for (i in 1:length(diffCol)) x=cbind(x,NA)
    colnames(x)=c(cols,diffCol)
  }
  return(rbind(x, y[, colnames(x)]))
}



#--0.
#--1. READING THE COMMAND LINE---

cmdargs = commandArgs(trailingOnly=T)
ID=cmdargs[1]
#RUN_ID=cmdargs[1]

SITE=cmdargs[2]
SitePostfix<-SITE


logDir=cmdargs[3]
#LOG_FILE<-paste(logDir, '/',RUN_ID,'_',SITE,'.log',sep='')

resDir=cmdargs[4]
Results_CSV_Path<-paste(resDir,'/',ID,'_',sep='')

ROI_LIST_TXT=cmdargs[5]
ROI_LIST<-readChar(ROI_LIST_TXT, file.info(ROI_LIST_TXT)$size)
ROI<-eval(parse(text=paste('c(',ROI_LIST,')',sep='')))


Config_Path=cmdargs[6]   #docs.google 

#Uyen changed: Read from google sheet via Python/reticulate pkg
source_python("retrieve_gsheets.py")
pyConfigVars = r_to_py(c(ID, Config_Path))
config_currentRun = getSheetConfig(pyConfigVars)

if(nrow(config_currentRun)>1) {
  cat (paste("Error: number of rows with ID ",ID," is more than 1. Row must be unique.",sep=''))
  stop()
}

AnalysisList_Path<-r_to_py(as.character(config_currentRun$AnalysisList_Path))
DemographicsList_Path<-r_to_py(as.character(config_currentRun$DemographicsList_Path))

#Uyen changed: read using Python function
dsAnalysisConf<-openSaveGSheet(AnalysisList_Path)
#read demographic configuration file
dsDemographicsConf<-openSaveGSheet(DemographicsList_Path)

cat(paste("Analysis list path: ",AnalysisList_Path,sep=''))
TYPE<-config_currentRun$Type
TRAIT_LIST<-config_currentRun$Trait
TRAIT_LIST<-gsub("[[:space:]]", "", TRAIT_LIST)
TRAIT_LIST<-gsub(";","\",\"",TRAIT_LIST)
METRICS<-eval(parse(text=paste('c("',TRAIT_LIST,'")',sep='')))

curModelInvalid<-FALSE
for(trait in METRICS){
  for (cur_rowAnalysis in 1:nrow(dsAnalysisConf)){
    i=1
    setwd(resDir)
    curModelInvalid<-FALSE
    if (dsAnalysisConf$Active[cur_rowAnalysis]==1) 
    {
      
      for (cur_roi in ROI) {
        f_name=paste(ID,'_',cur_roi,'_',trait,'_',dsAnalysisConf$ID[cur_rowAnalysis],'_',SitePostfix,'.csv',sep='')
	if (!(file.exists(f_name))) {
		cat(paste("File ",f_name," for METRICS: ", trait, " Linear model: ", dsAnalysisConf$ID[cur_rowAnalysis], " ROI: ", cur_roi, " does not exist. Skipping the whole model.\n"))
		curModelInvalid<<-TRUE
		break
	}
        cur_csv<-read.csv(f_name, header = TRUE,sep=',',dec='.')
        if(i==1) {
          data_csv<-cur_csv
        }
        else{
		data_csv<-rbind.ordered(data_csv, cur_csv)
#          data_csv<-rbind(data_csv,cur_csv,deparse.level = 0)
        }
        i=i+1
      }
      if(!curModelInvalid) write.csv(data_csv,file=paste(ID,'_ALL_',trait,'_',dsAnalysisConf$ID[cur_rowAnalysis],'_',SitePostfix,'.csv',sep=''))
    }
  }
}
