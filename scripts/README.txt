---README for mass_uv_regr package of scripts---

Dmitry Isaev
Boris Gutman
Neda Jahanshad

Beta version for testing on sites.
ENIGMA Project, 3.1.015
-----------------------------------------------
0. THIS IS THE BETA VERSION. Please check your analyses and results!! More complex models which use filters and new regressors may not have been tested using the combinations you have entered, so please let us know if you encounter any problems or have concerns. 
The script will create log files in the **log** directory. If you note an "Error" in a log file, please double check the analysis and send questions to us (Dmitry, Boris or Neda) at enigma@ini.usc.edu. 

1. The scripts folder consists of 5 files:
	* mass_uv_regr.bash - wrapper that can be used with/or without qsub for running over either csv or shape data
	* mass_uv_regr.R - R-based regression code for processing data
	* retrieve_gsheets.py - Python executable code used to pull from google sheets
	* concat_mass_uv_regr_csv.bash - wrapper that can be used with/or without qsub for concatenating regression results from all ROIs
	* concat_mass_uv_regr.R - R executable code for concatenating results from all ROIs
	
.sh scripts should be modified to specify your local paths and files.

2. Installation. 
2.1 Prerequisites. R libraries:
The following packages should be installed for R (v. >=4.0.5):
	matrixStats
	RCurl
	ppcor
	moments
The following packages should be installed for Python (v. >=2.7:
	pandas
	requests
2.2 Configuring the shell script.
2.2.1 Give yourself permissions to everything in the folders
	chmod -R 755 ENIGMA_Regressions/*  
2.2.2  Section 1:
	scriptDir - directory of the script itself (the folder containing .sh and .R scripts
	resDir - directory for results
	logDir - directory for logs
2.2.3 Section 2. Main configuration section
	RUN_ID="IJSHAPES"
	CONFIG_PATH="https://docs.google.com/spreadsheets/d/1-ThyEvz1qMOlEOrm2yM86rD_KABr_YE4yqYmHogaQg0"
	
	CONFIG_PATH is the path to Google Sheets documents which contains the links to 2 other documents as well as Study ID, type (csv/raw) and Traits to be examined. 
	Working group leaders should contact us about making an entry in the shared docs so all sites can perform the same tests.
	All other users must create their own GOOGLE DOCS FILES FOR AnalysisList_Path and DemographicsList_Path fields in that document.
	
	RUN_ID - should be the same as the STUDY ID of interest in the Google Sheet.
	
	The script will take the links from the line of config file with RUN_ID and will run the models from these files.

	SITE="ENIGMA" - the name of site - the postfix for the resulting files
	DATADIR="/ENIGMA_Regression/testMe/data/" - folder where the data resides.
	ROI_LIST - list of ROIs (have pre-set value for shapes and csv, maybe no need to change it)
	SUBJECTS_COV=path to your local subjects and covariates file
	EXCLUDE_FILE=path to file with excluded subjects for each ROI (if you have one)
	METR_PREFIX - prefix for files with metrics (for instance if you have all files named as metr_FA.csv, metr_MD.csv, metr_AD.csv, etc)
(!!!)	Nnodes - number of nodes used for computation. This number should match with that you set in qsub command: qsub -q .... -t 1-"Nnodes" mass_uv_regr_...sh
	if you do not use grid and use just shell execution - use Nnodes=1. Otherwise set the number of nodes up to the number of ROIs.
2.2.4 Section 5. 
	Rbin - put here the path to R binary ( for which you installed the packages)
3. Configuring the linear models and descriptive statistics. Link to those are in the Google Docs file specified by CONFIG_PATH

3.1 Configuring the linear models Google Sheet. For example see https://docs.google.com/spreadsheets/d/1N98u4C_Tl2jaW_bFDtkdatOdfHNoR2NBAs60UWqL9YM
3.1.1 ID
- ID of each distinct linear model, results are written to the file with the name {GROUP_ID}_{METRICS}_{ROI}_{ID}_{SitePostfix}.csv, where METRICS={LogJacs|thick|FA|MD|etc...} 
3.1.2 Name
- for your own purposes, not used in the script.
3.1.3 LM
- the actual linear model, expressed in R syntax.
The names of the variables MUST EXACTLY MATCH those in the covariates file (see Subject_Path, p.6) 
Categorical variables should be embedded as 'factor(variable)'.

3.1.4 MainFactor
the factor for which hypothesis is tested.
if factor appears as 'factor(variable)' - then the Cohen's D statistic is obtained.
if factor appears as 'variable' - runs the general linear model as well as the partial correlation between the metric and the main factor of interest, taking into consideration all other variables in model.
Currently, the MainFactor HAS TO BE either CONTINUOUS, or have only TWO LEVELS in the covariates table. 

3.1.5 Filters_1, Filters_3.1.
- filters which should be applied to the data before fitting the linear model. Variables should be separated from other syntax with DOUBLE UNDERSCORE ON BOTH SIDES: __Variable__
3.1.6 Filters_3 - not used.
3.1.7 SiteRegressors - used if multiple Site variables present in covariates file (e.g. Site1,Site3.1., etc).
if 'all' is put into the field, all variables named like 'SiteN' are added to the model as regressors. if there's no such variables, no regressors will be added.
3.1.8 NewRegressors 
ONLY FOR VERY EXPERIENCED USERS :))) -- let us know if you want to learn to work with these!
New variables that can be created from existing. Applied before filtering, so new regressors can be used for filtering
3.1.9 ContValue,PatValue - value of variables used for t-test for 'factor' variable. By default, 0 and 1. If your variable like 'factor(ATBN)' is istead taking values '3.1.' and '3' you should put these values in the ContValue and PatValue fields.
3.1.10 Active.
SETS IF THE LINE WILL BE EXECUTED BY THE SCRIPT.
If you want some lines to be omitted in the run, for debugging purposes, set ACTIVE to 0.
3.1.11 Comments. 
Anything you like.
3.1.12 ContMin,PatMin - minimum amount of elements in controls/patient groups needed to run the test
3.1.13 SaveLM - should either be 1 or 0. If set to 1, then the linear models in R format are saved to the .RData variable (with the  name {GROUP_ID}_{METRICS}_LM_{ROI}_{ID}_{SitePostfix}.Rdata) in the results folder

4. Configuring descriptive statistics configuration. For Example see https://docs.google.com/spreadsheets/d/11sVXxrtfUf-YzppDpW96IODaVbi5itXtfzGHy9tIVmE
4.1 Type
One of three: METRICS,COV,NUM.
METRICS - statistics gathered from shape metrics (LogJacs, thick)
COV - statistics gathered from covariates
NUM - number of elements in the group.
4.2 varname - name of the variable.
for SHAPE_metrics section the resulting varname looks like: varname.statsName (e.g. patients.mu.raw, patients.sd.raw, etc).
for COV metrics section the resulting varname looks like: varname.statsName.Postfix(e.g. age.mu.all,age.sd.all,age.mu.dx0,age.sd.dx0, etc)
for NUM metrics the resulting varname looks like: varname.StatsName (e.g. n.fem,n.mal,n.fem.dx0, etc)
4.4. Filter - same principle as in (p. 2.5) - will be applied before the statistics is computed).
4.4 Stats, StatsNames - DON't CHANGE IT, let it work as it is. it basically makes R to gather the statistics (mean, sd, range) and put it into variable names (varname.mu, varname.sd, varname.range).
4.5 SepFile - DEPRECATED IN CURRENT VERSION. sets if the statistics should be gathered in separate .Rdata file.
4.6 Active - same as (p. 2.10) - the statistics is active only if this field is set to 1.
4.7 Covariate - for COV section tells the name of the Covariate from which to extract the data. Should EXACTLY match the covariate field name (see p. 6)
4.8 Postfix -  explained in (p. 4.2)

5. Running the script.
You can split this up for parallelized regressions if you Q-SUB it!
	qsub -t 1-#N# mass_uv_regr_csv.sh, where #N# is the Number of Nodes (Nnodes variable in your script)
-- or-- set the number of nodes (Nnodes variable) to 1 and run it command-line:
sh mass_uv_regr_csv.sh

6. After running the script you may want to concatenate .CSV files from each ROI.
For this you could use the script: concat_mass_uv_regr_csv.sh which calls concat_mass_uv_regr.R
Things you need to configure:

6.2 Section 1:
	scriptDir,
	resDir,
	logDir,
	- same as in mass_uv_regr.sh, see p. 2.2.2
6.3 Section 2:
	RUN_ID,
	CONFIG_PATH,
	SITE,
	ROI_LIST,
	- same as in mass_uv_regr.sh, see p. 2.2.3
6.4 Running the script:
sh  same as in mass_uv_regr.sh, see p. 2.2.2
6.5 Results: files {GROUP_ID}_{METRICS}_ALL_{MODEL_ID}_{SitePostfix}.csv - all ROI for the same model and same trait concatenated in one file.