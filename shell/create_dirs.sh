#!/bin/bash

# Script for creating directory structure for autopayment project
# Created by Shmyg
# LMD by Shmyg 12.12.2003

mkdir -p {control_files,log_files,data_files}/\
{center/{aval_1,aval_2,aval_3,eurobank,integral,portmone},\
crimea/{cash_1,cash_2,cash_3},\
dnepr/{dnipropetrovsk,kirovograd,kryvy_rig,zaporizhya},\
east/{donetsk,lugansk},\
nord,\
south/{kherson,mykolayiv,odessa_1,odessa_3},\
west/{lviv_1,lviv_2,uzhgorod}}
