#!/bin/bash
#$ -S /bin/bash
 

#----Wrapper for csv version of mass_uv_regr.R script.
#----See readme to change the parameters for your data
#-Dmitry Isaev
#-Boris Gutman
#-Neda Jahanshad
# Beta version for testing on sites.
#-Imaging Genetics Center, Keck School of Medicine, University of Southern California
#-ENIGMA Project, 2015
# enigma@ini.usc.edu 
# http://enigma.ini.usc.edu
#-----------------------------------------------

#---Section 1. Script directories
scriptDir=/<path_to_folder>/ENIGMA/scripts ; # directory where you have downloaded the ENIGMA R scripts
resDir=/<path_to_folder>/ENIGMA/results ; # directory where your results have been saved
logDir=/<path_to_folder>/ENIGMA/log ;  # directory where your log files are

#---Section 2. Configuration variables-----

RUN_ID="UCLA_EPI_Uyen_Test" ;
CONFIG_PATH="https://docs.google.com/spreadsheets/d/1-ThyEvz1qMOlEOrm2yM86rD_KABr_YE4yqYmHogaQg0"
SITE="UCLA" ;
ROI_LIST=( "L_bankssts_thickavg" "R_bankssts_thickavg" )

#---Section 5. R binary -- CHANGE this to reflect the full path or your R binary
Rbin=R

##############################################################################################
## no need to edit below this line!!
##############################################################################################
#---Section 6. DO NOT EDIT. Running the R script
#go into the folder where the script should be run
if [ ! -d $scriptDir ]
then
   "The script directory you indicated does not exist, please recheck this."
fi

if [ ! -d $resDir ]
then
   "The Results directory you indicated does not exist, please recheck this."
fi

if [ ! -d $logDir ]
then
   "The Log directory you indicated does not exist, please recheck this."
fi

#Uyen changed: removed requirement for another text file with ROIs, seems unnecessary
ROI_FILE=$logDir/ROI_LIST.txt
touch $ROI_FILE

#for Uyen's sanity
> $ROI_FILE

for ROI in "${ROI_LIST[@]::${#ROI_LIST[@]}-1}"; do
	echo -n -e "\"${ROI}\"," >> $ROI_FILE
done
echo -n -e "\"${ROI_LIST[-1]}\"" >> $ROI_FILE

# for ROI in "${ROI_LIST[@]}"; do
# 	echo -n "\"${ROI}\"," >> $ROI_FILE
# done
# echo "\b"

OUT=$logDir/log_concat.txt
touch $OUT
cmd="${Rbin} --no-save --slave --args\
		${RUN_ID}\
		${SITE} \
		${logDir} \
		${resDir} \
		${ROI_FILE} \
		${CONFIG_PATH} \
		<  ${scriptDir}/concat_mass_uv_regr.R"
echo $cmd >> $OUT
eval $cmd
