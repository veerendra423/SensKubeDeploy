#!/bin/bash
  
AZ_CONTAINER_NAME=sensoriant-dev-storage
AZ_ACCOUNT_NAME=sensoriantdevstorage
AZ_ACCOUNT_KEY=J54rSHjUZqPk5BkCRo45iyGojgXeARhKYibdHpQRF3BNViMd6d86szbqzIOFXJIPAAzuDmUU4vSfI6LYhkEWGA==
SENS_OUTPUT_REG=?-Sens_Output_?
Default_DS_REG=*Default_DS_*
Sensarchiver=.sensarchiver/*
Sensarchiver_other=*sensarchiver-*
Keys=.keys/*
PipelineJsons=.pipelineJsons/*
run_cleanup()
{
   echo $1
   echo $AZ_CONTAINER_NAME
   echo $AZ_ACCOUNT_NAME
   echo $AZ_ACCOUNT_KEY
   date=`date -d "7 days ago" '+%Y-%m-%dT%H:%MZ'`
   az storage blob delete-batch -s $AZ_CONTAINER_NAME --pattern $1 --account-name $AZ_ACCOUNT_NAME --account-key $AZ_ACCOUNT_KEY --if-unmodified-since $date
}
cleanup_all()
{
 cleanup_keys
 cleanup_pipelineJsons 
 cleanup_sens_output
 cleanup_data_set
 cleanup_Sensarchiver
}
cleanup_keys()
{  
        echo "++++++++++++++++++++++++Start Keys cleanup++++++++++++++"
        run_cleanup $Keys
        echo "++++++++++++++++++++++++End Keys cleanup++++++++++++++++"
}
cleanup_pipelineJsons()
{  
        echo "++++++++++++++++++++++++Start PipelineJsons cleanup++++++++++++++"
        run_cleanup $PipelineJsons
        echo "++++++++++++++++++++++++End PipelineJsons cleanup++++++++++++++++"
}

cleanup_sens_output()
{  
	echo "++++++++++++++++++++++++Start Sens_Output cleanup++++++++++++++"
	run_cleanup $SENS_OUTPUT_REG
	echo "++++++++++++++++++++++++End Sens_Output cleanup++++++++++++++++"
}

cleanup_data_set()
{  
	echo "++++++++++++++++++++++++Start Default_DS cleanup++++++++++++++"
	run_cleanup $Default_DS_REG
	echo "++++++++++++++++++++++++End Default_DS cleanup++++++++++++++++"
}
cleanup_Sensarchiver()
{
	echo "++++++++++++++++++++++++Start Sensarchiver cleanup++++++++++++++"
        run_cleanup $Sensarchiver
	run_cleanup $Sensarchiver_other
        echo "++++++++++++++++++++++++End Sensarchiver cleanup++++++++++++++++"
}

cleanup_all

