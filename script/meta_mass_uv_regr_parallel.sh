#!/bin/bash
#$ -S /bin/bash
 

#----Wrapper for csv version of meta_mass_uv_regr.R script.
#----See readme to change the parameters for your data
#-Dmitry Isaev
#-Boris Gutman
#-Neda Jahanshad
# Beta version for testing on sites.
#-Imaging Genetics Center  Keck School of Medicine  University of Southern California
#-ENIGMA Project  2015
# enigma@ini.usc.edu 
# http://enigma.ini.usc.edu
#-----------------------------------------------

#---Section 1. Script directories

scriptDir="/ENIGMA_Regressions/mass_uv_regr_test/scripts" # where you have downloaded the ENIGMA Regression R scripts!
resDir="/ENIGMA_Regressions/mass_uv_regr_test/META/results"   ## directory to be created for your results!
logDir="/ENIGMA_Regressions/mass_uv_regr_test/META/logs"  ## directory to be created to output the log files

#---Section 2. Configuration variables-----
## Get the following from your working group leader ## 
RUN_ID="Your study ID"
CONFIG_PATH="https://docs.google.com/spreadsheets/d/1-ThyEvz1qMOlEOrm2yM86rD_KABr_YE4yqYmHogaQg0"
SITE_LIST_TXT="$scriptDir/site_list.txt"
NVERTEX="1"
ROI_LIST=("ACR" "ACR_L" "ACR_R" "ALIC" "ALIC_L" "ALIC_R") 

#ROI_LIST=("10" "11" "12" "13" "17" "18" "26" "49" "50" "51" "52" "53" "54" "58")
#VERTEX_LIST=("2502" "2502" "2502" "1254" "2502" "1368" "930" "2502" "2502" "2502" "1254" "2502" "1368" "930")
############

#Nnodes=${#ROI_LIST[@]}
Nnodes=1		# *** otherwise we're going to set the number of nodes to 1 and assume you are running locally

#---Section 4. DO NOT EDIT. qsub variable ---
#cur_roi=${ROI_LIST[${SGE_TASK_ID}-1]}  
Nroi=${#ROI_LIST[@]}	
if [ $Nnodes == 1 ]
then
	SGE_TASK_ID=1
fi
NchunksPerTask=$((Nroi/Nnodes))
start_pt=$(($((${SGE_TASK_ID}-1))*${NchunksPerTask}+1))
end_pt=$((${SGE_TASK_ID}*${NchunksPerTask}))

if [ "$SGE_TASK_ID" == "$Nnodes" ]
then
end_pt=$((${Nroi}))
fi

#---Set the full path to your R binary
Rbin=/usr/local/R-3.2.3/bin/R


######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## 
######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## 
######## no need to edit below this line ##########
######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## ######## 
#---Section 3. DO NOT EDIT. some additional processing of arbitrary variables

if [ ! -d $scriptDir ]
then
   mkdir -p $scriptDir
fi

if [ ! -d $resDir ]
then
   mkdir -p $resDir
fi

if [ ! -d $logDir ]
then
   mkdir -p $logDir
fi


#---Section 6. DO NOT EDIT. Running the R script

OUT=$scriptDir/log.txt
touch $OUT
for ((i=${start_pt}; i<=${end_pt};i++));
do
	cur_roi=${ROI_LIST[$i-1]} 
#	NVERTEX=${VERTEX_LIST[$i-1]} 
cmd="${Rbin} --no-save --slave --args\
		${RUN_ID}\
		${resDir} \
		${logDir} \
		${NVERTEX} \
		${cur_roi} \
		${SITE_LIST_TXT} \
		${CONFIG_PATH} \
		<  ${scriptDir}/meta_mass_uv_regr_parallel.R
	"
echo $cmd
echo $cmd >> $OUT
eval $cmd
done
