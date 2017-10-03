# -*- coding: utf-8 -*-
"""
Created on Tue Oct 03 18:06:57 2017

@author: wildcat
"""

import csv
import sqlite3

import os
os.chdir('C:\Users\wildcat\Documents\GitHub\daen690fall2017crypto')
print os.getcwd()

import pandas as pd
import numpy as np

df = pd.read_csv('crytpo.csv')
df

