#!/bin/bash

#---Section 1. Script directories
scriptDir=/<path_to_folder>/ENIGMA/scripts ;
resDir=/<path_to_folder>/ENIGMA/results ;
logDir=/<path_to_folder>/ENIGMA/log ;

# Init bash
source ~/.bashrc ;

#---Set up environment here, if using one
conda activate MassUVEnv;

#---Section 2. Configuration variables-----
RUN_ID="UCLA_EPI_Uyen_Test" ;
CONFIG_PATH="https://docs.google.com/spreadsheets/d/1-ThyEvz1qMOlEOrm2yM86rD_KABr_YE4yqYmHogaQg0" ;
SITE="UCLA" ;
DATADIR="/<path_to_folder>/ENIGMA/data" ;

# ROI_LIST=( "L_bankssts_thickavg" "L_caudalanteriorcingulate_thickavg" "L_caudalmiddlefrontal_thickavg" "L_cuneus_thickavg" "L_entorhil_thickavg" "L_fusiform_thickavg" "L_inferiorparietal_thickavg" "L_inferiortemporal_thickavg" "L_isthmuscingulate_thickavg" "L_lateraloccipital_thickavg" "L_lateralorbitofrontal_thickavg" "L_lingual_thickavg" "L_medialorbitofrontal_thickavg" "L_middletemporal_thickavg" "L_parahippocampal_thickavg" "L_paracentral_thickavg" "L_parsopercularis_thickavg" "L_parsorbitalis_thickavg" "L_parstriangularis_thickavg" "L_pericalcarine_thickavg" "L_postcentral_thickavg" "L_posteriorcingulate_thickavg" "L_precentral_thickavg" "L_precuneus_thickavg" "L_rostralanteriorcingulate_thickavg" "L_rostralmiddlefrontal_thickavg" "L_superiorfrontal_thickavg" "L_superiorparietal_thickavg" "L_superiortemporal_thickavg" "L_supramargil_thickavg" "L_frontalpole_thickavg" "L_temporalpole_thickavg" "L_transversetemporal_thickavg" "L_insula_thickavg" "R_bankssts_thickavg" "R_caudalanteriorcingulate_thickavg" "R_caudalmiddlefrontal_thickavg" "R_cuneus_thickavg" "R_entorhil_thickavg" "R_fusiform_thickavg" "R_inferiorparietal_thickavg" "R_inferiortemporal_thickavg" "R_isthmuscingulate_thickavg" "R_lateraloccipital_thickavg" "R_lateralorbitofrontal_thickavg" "R_lingual_thickavg" "R_medialorbitofrontal_thickavg" "R_middletemporal_thickavg" "R_parahippocampal_thickavg" "R_paracentral_thickavg" "R_parsopercularis_thickavg" "R_parsorbitalis_thickavg" "R_parstriangularis_thickavg" "R_pericalcarine_thickavg" "R_postcentral_thickavg" "R_posteriorcingulate_thickavg" "R_precentral_thickavg" "R_precuneus_thickavg" "R_rostralanteriorcingulate_thickavg" "R_rostralmiddlefrontal_thickavg" "R_superiorfrontal_thickavg" "R_superiorparietal_thickavg" "R_superiortemporal_thickavg" "R_supramargil_thickavg" "R_frontalpole_thickavg" "R_temporalpole_thickavg" "R_transversetemporal_thickavg" "R_insula_thickavg" ) ;
ROI_LIST=( "L_bankssts_thickavg" "R_bankssts_thickavg" )

SUBJECTS_COV="/<path_to_folder>/ENIGMA/data/covariates.csv" ;
EXCLUDE_FILE="" ;
QA_LEVEL="" ;
METR_PREFIX="metr_"

# Create a number for how many nodes we are processing (length of ROI list)
Nnodes=${#ROI_LIST[@]}

#---Section 5. R binary
#Rbin=/usr/local/R-2.9.2_64bit/bin/R
#Rbin=/usr/local/R-3.2.3/bin/R
#Rbin=/usr/local/R-3.5.1/bin/R
Rbin=R

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

# -- Sanity Check -- $$ 

for ROI in "${ROI_LIST[@]}"; do
    
    sanOUT=$logDir/fileLocations.txt ;
    touch $sanOUT
    
    echo "RUN ID:" ${RUN_ID} >> $sanOUT
    echo "SITE:" ${SITE} >> $sanOUT
    echo "DATA DIR:" ${DATADIR} >> $sanOUT
    echo "logDir:" ${logDir} >> $sanOUT
    echo "resDir:" ${resDir} >> $sanOUT
    echo "SUBJECTS_COV:" ${SUBJECTS_COV} >> $sanOUT
    echo "ROI:" ${ROI} >> $sanOUT
    echo "CONFIG_PATH:" ${CONFIG_PATH} >> $sanOUT
    echo "QA_LEVEL:" ${QA_LEVEL}  >> $sanOUT
    echo "EXCLUDE_STR:" ${EXCLUDE_STR} >> $sanOUT
    echo "METR_PREFIX:" ${METR_PREFIX} >> $sanOUT
    echo "" >> $sanOUT
    echo "" >> $sanOUT
    echo "" >> $sanOUT

    ${Rbin} --no-save --slave --args\
    ${RUN_ID}\
    ${SITE} \
    ${DATADIR} \
    ${logDir} \
    ${resDir} \
    ${SUBJECTS_COV} \
    ${ROI} \
    ${CONFIG_PATH} \
    ${QA_LEVEL}  \
    ${EXCLUDE_STR} \
    ${METR_PREFIX} < ${scriptDir}/mass_uv_regr.R ;
    
done