#!/bin/sh

##########################################
# 
# USAGE:
# Runtime arguments: 
#   $1 = repo
#   $2 = folder with function
#   $3 = region 
#   $4 = new function name
#
##########################################

mkdir temp
cd temp
git clone $1 .
sourcepath=$2/source
gcloud functions deploy --source=$sourcepath --region=$3 --trigger-http --runtime=python37 --entry-point=execute $4
cd ..
rm -rf temp
