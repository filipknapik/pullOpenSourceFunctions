#!/bin/bash

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

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}
config_path=$2/config.yml
env_vars_counter=0
my_array=( $(parse_yaml $config_path) )
touch env_vars.yml
for i in "${my_array[@]}"
do
    if  [[ $i == "env_vars_"* ]] && [[ $i == *"\"mandatory\"" ]] ;
    then
        ((env_vars_counter++))
        foo=${i#"env_vars_"}
        foo=${foo%"=\"mandatory\""}
        read -p "Enter value for environment variable \""$foo"\":"  input
        echo $foo": "$input >> env_vars.yml
    fi
done

if [ "$env_vars_counter" -eq "0" ]; 
    then
    gcloud functions deploy --source=$sourcepath --region=$3 --trigger-http --runtime=python37 --entry-point=execute $4
    else
    gcloud functions deploy --source=$sourcepath --region=$3 --trigger-http --runtime=python37 --entry-point=execute --env-vars-file env_vars.yml $4
fi

cd ..
rm -rf temp
