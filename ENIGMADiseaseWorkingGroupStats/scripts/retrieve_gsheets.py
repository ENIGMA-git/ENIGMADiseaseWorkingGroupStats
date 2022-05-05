import os
import sys
import pandas as pd
import csv
import requests

def getSheetConfig(CONFIG_VAR):
    config_url = "".join([CONFIG_VAR[1], "/export?format=csv"])
    config_csv = pd.read_csv(config_url)
    config_currentRun = config_csv.loc[config_csv['ID'] == CONFIG_VAR[0]]
    #config_path = "".join([logDir, '/', RUN_ID, '_', 'Config.csv'])
    #pd.config_currentRun.to_csv(config_path)
    return config_currentRun

def openSaveGSheet(url):
    urlExport = "".join([url, "/export?format=csv"])
    with requests.Session() as s:
        download = s.get(urlExport)
        decoded_content = download.content.decode('utf-8')
        cr = csv.reader(decoded_content.splitlines(), delimiter=',')
        my_list = list(cr)
        df = pd.DataFrame(my_list[1:len(my_list)], index=None, columns=my_list[0])
        print(df)
    return df