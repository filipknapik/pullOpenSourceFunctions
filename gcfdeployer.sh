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
serv_acc=""
secret_function=""
access_key=""
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
    if  [[ $i == "other_prompts_service_account"* ]] && [[ $i == *"\"mandatory\"" ]];
    then
        read -p "Enter e-mail address of the service account that this function will use:"  serv_acc 
    fi
    if  [[ $i == "secrets"* ]] && [ -z "$secret_function" ];
    then
        read -p "Enter URL of the Secrets function in this project:"  secret_function 
    fi
    if  [[ $i == "secrets"* ]] && [ -z "$access_key" ];
    then
        read -p "Enter access key for the Secrets function in this project:"  access_key 
    fi
    if  [[ $i == "secrets"* ]];
    then
        keyname=${i#"secrets_"}
        keyname=${keyname%"=\"mandatory\""}
        read -p "Enter value for secret \""$keyname"\":"  secret_value
        curl -X POST -H 'Content-type: application/json' -d '{"action":"storesecret", "access_key":"'$access_key'", "secret_key":"'$keyname'","secret_value":"'$secret_value'"}' $secret_function
    fi
done

if [ "$env_vars_counter" -eq "0" ]; 
    then
        env_vars_file=""
    else
        env_vars_file="--env-vars-file env_vars.yml"
fi

if [ -z "$serv_acc" ]
    then
        serv_acc_param=""
    else
        serv_acc_param="--service-account="$serv_acc
fi

gcloud functions deploy --source=$sourcepath --region=$3 --trigger-http --runtime=python37 --entry-point=execute $env_vars_file $serv_acc_param $4

cd ..
rm -rf temp
