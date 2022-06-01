# ENIGMA Effect size and GLM script
*Dmitry Isaev, Sinead Kelly, Boris Gutman, Neda Jahanshad*

The script is intended for the batch processing of multiple linear models, and the results can easily be carried forward to meta-analysis with provided scripts. 
Each working group may configure its own set of linear models, depending on imaging metrics and covariates data it has.
Imaging metrics could be: **average ROI values (FA, volume etc.) in a .csv file ** or **shape vertexwise values** listed as paths in a .csv file.
The working group project leader is the one to configure the files and set up the models for the analysis. Project participants then simply name the appropriate analysis in the scripts before running. When running the scripts, internat connection is necessary.  
For project leaders setting up the configuration -- In this initial implementation, the configuring scripts for ROI values listed in a .csv and vertexwise data listed as file paths in the .csv need to be set up differently, so we explain each separately below.

### System requirements
You need **R version 4.0.5 or later** and **Python version 2.7.0 or later** to run these scripts. Please install it yourself or ask the administrator of your system to install it, before you start configuring and testing scripts.

### Contents of the package
The following scripts should be downloaded from GitHub:
- Script shell-wrapper (*mass_uv_regr.sh file on end user machine*)
- The R executable code (*mass_uv_regr.R file on end user machine*)
- Python executable code (*retrieve_gsheets.py file on end user machine*)
- Shell-wrapper for script for concatenating results from all ROIs (*concat_mass_uv_regr\[_csv\].sh file on end user machine*)
- The R executable code for concatenating results from all ROIs (*concat_mass_uv_regr\[_csv\].R file on end user machine*)
In order to run the package, you will also need to supply the following data:
- Linear Models and Demographics statistics configuration file (*Upload both to to Google Docs*)
- Average ROI imaging measures/vertexwise shape measures (*shape output .raw or average ROI .csv files on end user machine*)
- Covariates files (*.csv files on end user machine*)

# Step by step tutorial on setting up your analysis with Average ROI metrics
This section is a step-by-step tutorial on setting up analysis with Average ROI metrics.
As an example of pre-configured scripts and data files, you can go to [example_tutorial](https://github.com/dyisaev/ENIGMA/tree/master/WorkingGroups/EffectSize_and_GLM/example_tutorial)


### Step 1. Prepare directory structure
Create a folder on your machine/server where you will be performing your analysis. For example:    

    mkdir /<path-to-your-folder>/ENIGMA

In that folder create 4 subfolders where you will put your data, logs, results and scripts. For example:

    mkdir /<path-to-your-folder>/ENIGMA/data
    mkdir /<path-to-your-folder>/ENIGMA/logs
    mkdir /<path-to-your-folder>/ENIGMA/results
    mkdir /<path-to-your-folder>/ENIGMA/scripts

### Step 2. Prepare metrics CSV files
Create or copy your existing metrics files to `data` folder. Metrics file should have name `prefix_TRAIT.csv`, where `prefix` is any string, and `TRAIT` - the name of metric, contained in that file. For example:
```
    /<path-to-your-folder>/ENIGMA/data/metr_FA.csv
    /<path-to-your-folder>/ENIGMA/data/metr_MD.csv
    /<path-to-your-folder>/ENIGMA/data/metr_AD.csv
    /<path-to-your-folder>/ENIGMA/data/metr_RD.csv
``` 
\- are traditional Diffusion Tensor FA, MD, AD, RD metrics.

Please mind, that *Each metrics should have its separate file*.

Required structure of metrics file:

SubjID | ROI_Name1 | ROI_Name2 | ... | ROI_Name#N
-------|-----------|-----------|-----|-----------
\<ID_1\>|0.42|0.81| ... | 0.64
\<ID_2\>|0.61|0.58| ... | 0.55
...|...|...|...|...

**SubjID** column name should not be changed. You will later need list of ROI names (ROI_name1, ROI_name2, etc.) for configuring shell script, so keep them meaningful. Please take a look at the [Example of metr_FA.csv](https://github.com/dyisaev/ENIGMA/blob/master/WorkingGroups/EffectSize_and_GLM/example_tutorial/data/metr_FA.csv).

### Step 3. Prepare your covariates CSV file.
Create or copy your covariates file to `data` folder. For example:
```
    /<path-to-your-folder>/ENIGMA/data/covariates.csv    
```
Example structure of covariates file:

SubjID | Site | Age | Sex |... 
-------|------|-----|-----|---
\<ID_1\>|USC|34| 1 | ... 
\<ID_2\>|USC|37| 0 | ...
...|...|...|...|...

**SubjID** column name should not be changed. If you do a multi-site study, then **Site** column is obligatory.  Please check that Subject IDs and number of rows in covariates and metrics CSV match. It's necessary for correct script performance. Please take a look at the [Example of covariates.csv](http://covariates.csv)


### Step 4. Prepare QA analysis file (if you have one).
From the ENIGMA Shape analysis, if you did automatic QA, please copy your QA analysis output .csv file to `data` folder. For example:
```
	/<path-to-your-folder>/ENIGMA/data/QA.csv
```
Required structure of QA file:


SubjID | **ROI**\<ROI_Name1\> | **ROI**\<ROI_Name2\> | ... | **ROI**\<ROI_Name#N\>
-------|-----------|-----------|-----|-----------
\<ID_1\>|3|2| ... | 1
\<ID_2\>|1|2| ... | 3
...|...|...|...|...

**SubjID** column name should not be changed. Columns corresponding to ROIs have to have prefix **ROI** and then real ROI name(same as in metrics and covariates CSV files) without any space.

### Step 5. Register your study in ENIGMA-Analysis Google Sheet (Should be done by Group Leader).
Main configuration file is [ENIGMA Analysis Google Sheet](https://docs.google.com/spreadsheets/d/1-ThyEvz1qMOlEOrm2yM86rD_KABr_YE4yqYmHogaQg0), that is shared by all group leaders, each of them owning one or several lines in the sheet.
#### ENIGMA Analysis Google Sheet structure
[ENIGMA Analysis Google Sheet](https://docs.google.com/spreadsheets/d/1-ThyEvz1qMOlEOrm2yM86rD_KABr_YE4yqYmHogaQg0) consists of the following columns:

1. **ID**. Unique ID of your study
2. **AnalysisList_Path**. Link to Google Sheet with configuration of your Linear Models.
3. **DemographicsList_Path**. Link to Google Sheet with configuration for descriptive statistics you want to gather from your sample (mean Age, amount of Men/Women, mean Age of Men/Women, etc.).
4. **Type**. Can take either of two values: **raw**/**csv**. Use **raw** if your study is dealing with shape data. Use **csv** if you read average ROI metrics from .csv files.
5. **Trait**. List metric names that correspond to names of your csv file name. If your metrics files are named `metr_FA.csv`, `metr_MD.csv`, `metr_AD.csv`, `metr_RD.csv` then your **Trait** field should be `FA; MD; AD; RD`. **Names should be separated with semicolon and a space**. 
See [Example for ENIGMA Analysis Google Sheet](https://docs.google.com/spreadsheets/d/142eQItt4C_EJQff56-cpwlUPK7QmPICOgSHfnhGWx-w) and checkout **ENIGMA_TUTORIAL** line.

### Step 6. Create Linear Model Google Sheet (AnalysisList_Path).
Configuring the linear models Google Sheet. For example see [Example of Enigma Linear models Google sheet](https://docs.google.com/spreadsheets/d/116R3FrZsfj842_DQkhbukXGWm9p1hdpddi3s3qvPucE)
Overall you may do three different types of analysis with the package:

- effect size analysis (Cohen's D). In that case you should have two-level diagnosis variable, for which the system will compute the size of effect.
- Partial correlations. In that case you compute partial correlations between imaging metric and first variable in your analysis, controlling for all other variables included in your linear model.
- Linear model computing betas for all covariates, and outputting p-value for particular covariate of interest.

These three different behaviours are defined by 3 fields: **LM**,**MainFactor** and **FactorOfInterest**. 

- For Effect size analysis - see section 6.3
- For Partial correlations - see section 6.4
- For Beta and p-value - see section 6.5

#### 6.1. ID
- ID of each distinct linear model, results are written to the file with the name {GROUP_ID}_{METRICS}_{ROI}_{ID}_{SitePostfix}.csv, where METRICS={LogJacs|thick|FA|MD|etc...} 

#### 6.2 Name
- for your own purposes, not used in the script.

#### 6.3 Effect size analysis (Cohen's D).

##### 6.3.1 LM
The actual linear model, expressed in R syntax. Covariate, which effect size you want to find, **should go first in Linear Model formula**.
The names of the variables MUST EXACTLY MATCH those in the covariates file (see **Step 3**) 
Categorical variables should be embedded as 'factor(variable)'.

##### 6.3.2 MainFactor and FactorOfInterest
Variable, which effect size is of interest, should be listed as MainFactor. For example, if your LM=*'factor(Dx)+Age+Sex+Age:Sex'*, then your MainFactor should be *'factor(Dx)'*. FactorOfInterest should be left empty.

#### 6.4 Partial correlations analysis.

##### 6.4.1 LM
The actual linear model, expressed in R syntax. Covariate, which you want to correlate with imaging metrics , **should go first in Linear Model formula**.
The names of the variables MUST EXACTLY MATCH those in the covariates file (see **Step 3**) 
LM should not contain variables embedded as 'factor(variable)'. For partial correlations to work properly, all variables have to be continious.

##### 6.4.2 MainFactor and FactorOfInterest
Covariate, for which we want to get partial correlations, should be listed in the field MainFactor. For example, if your LM=*'Age+Sex+Age:Sex'*, and you're looking for correlations between imaging metrics and Age, then your MainFactor should be *'Age'*. FactorOfInterest should be left empty. Mind, that Age should go in first place in Linear Model.

#### 6.5 Beta and p-value for particular variable.
If we just want to output beta and p-value for particular covariate, we should put it in first place in Linear Model, and put it's name into "FactorOfInterest" field.
##### 6.5.1 LM
Except putting factor of interest in first place, no special restrictions are set on linear model.
##### 6.5.2 MainFactor and FactorOfInterest
MainFactor should be left empty. FactorOfInterest should represent the name of the covariate for which we need beta and p-value.

#### 6.6 Adding filters (Filters_1, Filters_2)

In the Filters columns, various filters for the data can be applied.  Variables should be separated from other syntax with DOUBLE UNDERSCORE ON BOTH SIDES: \_\_Variable\_\_.
For example, if you want to investigate the effects of age at onset in patients only, include: 
	
	(__Dx__==1) & (!is.na(__AO__))

Here, we assume that patients are coded as “1” and age at onset is coded as “AO”

If you have a variable that has multiple levels, e.g antipsychotic medication (unmediated, typical, atypical, both), you may want to include more than one filter for individual t-tests between these groups. 
In this example, we may want to compare patients on atypical medication with patients on typical medication (excluding the other two medication groups, as well as healthy controls).
In this case, we would add the first filter to look at patients only and then patients on typical medication (assuming patients on typical medication are coded as “2” in your antipsychotic (“AP”) variable):

	(__Dx__==1) & (__AP__==2)

Then, in the second filter column, you will filter for patients only, as well as patients on atypical medication (assuming atypical patients are coded as “3” in your “AP” variable):

	(__Dx__==1) & (__AP__==3)

Finally, in the ‘ContValue’ and ‘PatValue’ columns, enter “2” and “3” respectively, to indicate that you are comparing groups 2 and 3 for your antipsychotic medication (“AP”) variable. 

*Filters_3 column should not be used.*

#### 6.7 SiteRegressors 
- used if multiple Site variables present in covariates file (e.g. Site1,Site3.1., etc). If 'all' is put into the field, all variables named like 'SiteN' are added to the model as regressors. if there's no such variables, no regressors will be added.

#### 6.8 NewRegressors 

In the “NewRegressers” column, you can introduce new regressors that may not be included in your covariate spreadsheets. For example, if you want to also covary for age demeaned (“AgeC”), enter a formula to calculate “AgeC”:

	__AgeC__=__Age__-mean(__Age__)

If you want to covary for Age demeaned squared (“AgeC2”), enter the following (all in the same cell):

	__AgeC__=__Age__-mean(__Age__); __AgeC2__=__AgeC__*__AgeC__

In the example config file you will see formulas for age demeaned by sex (“AgeCSex”), age squared demeaned (“Age2C”), and Age squared demeaned by sex (“Age2CSex”)
These new variables can then be included as covariates in linear model (‘LM’ column):
	
	factor(Dx) + Age + factor(Sex) + AgeCSex +Age2C + Age2CSex

New regressors are created  before filtering, so they in turn can be used for filtering.

#### 6.9 ContValue,PatValue 
- value of variables used for t-test for 'factor' variable. By default, 0 and 1. If your variable like 'factor(ATBN)' is instead taking values '2' and '3' you should put these values in the ContValue and PatValue fields.

#### 6.10 Active.
In the ‘Active’ column, you can activate the individual tests by entering “1” or deactivate individual tests by entering “0”.

#### 6.11 Comments. 
Anything you like.

#### 6.12 ContMin,PatMin 
- minimum amount of elements in controls/patient groups needed to run the test

#### 6.13 SaveLM 
- should either be 1 or 0. If set to 1, then the linear models in R format are saved to the .RData variable (with the  name {GROUP_ID}_{METRICS}_LM_{ROI}_{ID}_{SitePostfix}.Rdata) in the results folder

### Step 7. Create Demographics Google Sheet (DemographicsList_Path).
This file specifies the descriptive statistics you want to obtain. 
Three types of descriptive statistics can be specified in this file:

- METRICS
- COV
- NUM

#### 7.1. Metrics
**METRICS** will output summary information (mean, sd, min, max) for each imaging measure (e.g. FA, volume, thickness) for each ROI or structure.  You can also split this up based on the groups in your analysis (patients, controls, medicated patients, unmedicated patients etc). See the ‘Filter’ column.  ‘Stats’ and ‘StatsNames’ columns indicate the statistics you want to obtain (sd, mean etc). 

#### 7.2. COV (Covariates)
**COV** obtains descriptive statistics (mean, sd, range) for each of your continuous variables in the analysis (e.g. age, duration of illness, age at onset etc.).  If you want to split this up in terms of your groups (patients, controls, medicated, unmedicated) use the ‘Filter’ column to specify your groups (see example). The ‘Covariate’ column will remain the same as the ‘Varname’ column and the ‘Postfix’ column will contain the postfix you want to give each output file. 

#### 7.3. NUM (amount of subjects in different subsets
**NUM** obtains the number (n) of participants for each categorical variable in your analysis (e.g. Diagnosis, Sex, medication type, smokers, non-smokers), but you also can filter subjects with continious variables (e.g. Age>30)
Using the ‘Filter’ column, indicate if you want n for:
Females only (assuming females are coded as “2”):

	(__Sex__==2)

Males only (assuming males are coded as “1”):

	(__Sex__==1)

Female healthy controls (assuming healthy controls are coded as “0’):

	(__Sex__==2) & (__Dx__==0)

Unmedicated females (assuming unmedicated patients are coded as “1”):

	(__Sex__==2) & (__AP__==1)

See example [Example DemographicsList Google Sheet](https://docs.google.com/spreadsheets/d/10YFVkYhKgDBsAnvkmCx7e_Iff2dmLJ0wyrsAbt82Cak) file for more filters.
The working group leader in this case can intuitively name the ‘StatsNames’ column.

‘Active’ columns can be left as “1” for active or “0” for inactive.

*'Sepfile' column is deprecated. Set it to 0*.

### Step 8. Download scripts and adjust mass_uv_regr_csv.sh
Download all files from the `script` folder on GitHub into `/<path-to-your-folder>/ENIGMA/scripts`.
Give yourself permissions to everything in the folders:

    chmod -R 755 /<path-to-your-folder>/ENIGMA/scripts  

Open `mass_uv_regr_csv.sh` in any text editor and configure as follows for your own analysis.

##### 8.1  Section 1:

- `scriptDir=/<path-to-your-folder>/ENIGMA/scripts`
- `resDir=/<path-to-your-folder>/ENIGMA/results`
- `logDir=/<path-to-your-folder>/ENIGMA/logs`

If you are using a conda or virtual environment, be sure set this up where indicated:
    
    conda activate <name_of_env>
##### 8.2 Section 2. Main configuration section

- `RUN_ID="<STUDY_ID>"` - Unique ID of your study from ENIGMA Analysis Google Docs file (see **Step 5**)
- `CONFIG_PATH="https://docs.google.com/spreadsheets/d/1-ThyEvz1qMOlEOrm2yM86rD_KABr_YE4yqYmHogaQg0"` - path to ENIGMA Analysis Google Docs file. The script will retrieve the row in the shared config file that matches your RUN_ID, read the AnalysisList_Path and DemographicsList_Path csvs from their respective links, and run the models from these files.
- `SITE="<SITE_NAME>"` - the name of particular site for which the script is being configured. It will become the postfix for the resulting files.
- `DATADIR="/<path-to-your-folder>/ENIGMA/data"` - folder where the covariates, metrics and QC files reside.
- `ROI_LIST` - list of ROIs (have pre-set value for shapes and csv, maybe no need to change it)
- `SUBJECTS_COV="/<path-to-your-folder>/ENIGMA/data/covariates.csv"`
- `EXCLUDE_FILE="/<path-to-your-folder>/ENIGMA/data/QA.csv"` path to QA file. (!!!) ADD QA_LEVEL
- `METR_PREFIX="metr_"` - prefix for files with metrics (for instance if you have all files named as metr_FA.csv, metr_MD.csv, metr_AD.csv, etc)
-  Nnodes - number of nodes used for computation. This number should match with that you set in qsub command: qsub -q .... -t 1-"Nnodes" mass_uv_regr_...sh. if you do not use grid and use just shell execution - use Nnodes=1. Otherwise set the number of nodes up to the number of ROIs.

##### 8.3 Section 5. Path to R binary 
- `Rbin="<path_to_R_binary>` - put here the path to R binary ( for which you installed the packages)

### Step 9. Make sure you have R & Python packages installed.
Before running the script you have to make sure you have all necessary libraries for R.
The following packages should be installed for R:
	`matrixStats`,
	`RCurl`,
	`ppcor`,
	`moments`
	`reticulate`.
	
And the following packages should be installed for Python:
  `os`
  `sys`
  `pandas`
  `csv`
  `requests`.

### Step 10. Running the script.
You can split this up for parallelized regressions if you Q-SUB it!

`qsub -t 1-#N# mass_uv_regr_csv.sh`, where `#N#` is the Number of Nodes (Nnodes variable in your script)

Another option is to set the number of nodes (**Nnodes** variable) to 1 and run it from command-line:

`sh mass_uv_regr_csv.sh`

### Step 11. Analyzing results.
To check that scripts worked correctly, one should go 'logs' and 'results' directories.
#### 11.1 Controlling the number of resulting .csv files
Main result of the script is **.csv** file for each metrics, linear model and ROI. So if script worked correctly, you at least should have N(metr)\*N(LM)\*N(ROI) **.csv** files.
To check that, you can `cd` to your `results` folder and do `wc -l` command:

	cd /<path-to-your-folder>/ENIGMA/results
	ls *.csv | wc -l

if the number does not match with your expected amount, it means that something went wrong, and you need to figure out why.
Usually, if something goes wrong - it goes wrong for some particular linear model, not for particular ROI or metrics.
#### 11.2 Checking logs for errors
To figure out what's going on you need to go to `logs` folder and open in text editor any **.log** file.
In the editor search for the line:

	`error_occ:1`

after each model computed the script outputs `error_occ:0` if everything went well, or `error_occ:1` if something went wrong (*'error_occ'* stands for *'error_occured'*).
If you find the line with *'error_occ:1'* you may scroll several lines up - you should find there `ERROR` (in capital letters), explainig very technically what has happened. 
**Most common problems are:**

- variable set as 'factor' has only one level, due to filtering
- several variables in the model are collinear

these usualy have to deal with phrases like `error in contrast(...)`.
We are working on creating more extended FAQ for troubleshooting models.
#### 11.3 Other checks
If you opted to save linear models (Save\_LM set to 1), then for each metric/ROI/LM you will have a file \_LM.RData. Usually they are outputted, and there's no problems with them.
also, for each ROI you will have METRIC/COV/NUM.RData. For COV and NUM that's redundant, but unfortunately that's how it works now.

### Step 12. Concatenating results for subsequent meta-analysis.
 After running the script you may want to concatenate .CSV files from each ROI.
For this you should use the script `concat_mass_uv_regr_csv.sh`, which calls `concat_mass_uv_regr.R`

You will need to configure the `concat_mass_uv_regr_csv.sh` script. Many of the variables are identical to those used in mass_uv_regr_loop.bash.

##### 12.2 Section 1:

	scriptDir,
	resDir,
	logDir,
	
\-same as in mass_uv_regr.sh, see **Step 8.1**
##### 12.2 Section 2:
	RUN_ID,
	CONFIG_PATH,
	SITE,
	ROI_LIST
\-same as in mass_uv_regr.sh, see **Step 8.2**

##### 12.3 Running the script:
	sh  concat_mass_uv_regr_csv.sh

### Step 13. Checking that concatenation worked fine
If everything went well, there should be a number of new **.csv** files in `results` folder.
Naming convention is {GROUP_ID}_{METRICS}_ALL_{MODEL_ID}_{SitePostfix}.csv - all ROI for the same model and same trait concatenated in one file.

So there should be N(Linear models)\*N(metrics) total files.

In case something went wrong, you may check `/<path-to-your-folder>/ENIGMA/logs/log_concat.txt`
