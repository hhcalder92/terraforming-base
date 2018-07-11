#!/bin/bash

IFS=$'\n'             # make newlines the only separator
IMPORT_FLAG='import'  # flag to import remote state
EXPORT_FLAG='export'  # flag to export local state
set -f                # disable globbing
source aws.env        # source aws creds

# Command file from Readme at https://github.com/dtan4/terraforming
TERRAFORMING_COMMAND_FILE=terraforming.txt

# Extra Parameters
TERRAFORMING_PARAMETERS="--profile ${AWS_TERRA_MOD:-calderon} --region=${AWS_REGION:-us-west-2}"

# import state
TERRAFORMING_STATE=${1:-none}

terragrunt_loop () {
 # Loop it
 echo "Loop it"
 for line in $(cat < "$TERRAFORMING_COMMAND_FILE"); do
   # Remove comment and add params
   cmd="${line%%#*}  $TERRAFORMING_PARAMETERS"

   IFS=' '
   read -r -a cmd_array <<< "$cmd"
   aws_service="${cmd_array[1]}"
   IFS=$'\n'

   echo "cmd: $cmd"

   case "$aws_service" in
    dbpg) echo -e "\tskip for now."  ;;
    kmsk) echo -e "\tskip for now."  ;;
    *)
      eval $cmd > ${aws_service}.tf

      minimumsize=2
      actualsize=$(wc -c <"${aws_service}.tf")

      if [ $actualsize -ge $minimumsize ]; then
          echo -e "\tsaved ${aws_service}.tf"
          if [ "$TERRAFORMING_STATE" == "$IMPORT_FLAG" ] ; then
           [ -e terraform.tfstate ] && MERGE_STATE=--merge=terraform.tfstate
           import_cmd="$cmd --tfstate $MERGE_STATE"

           # make sure terraform.tfstate exists
           [ -e terraform.tfstate ] || cp .tfstate.template terraform.tfstate

           # import command
           echo -e "\timporting: $import_cmd"
            eval $import_cmd > terraform.tfstate.new
            mv terraform.tfstate.new terraform.tfstate
          fi
      else
          rm ${aws_service}.tf
          echo -e "\tdeleted ${aws_service}.tf"
      fi
    ;;
   esac

   echo

 done
}

terraform_state_push_remote () {
 terraform plan
 terraform state push -force terraform.tfstate
 terraform plan
}

terragrunt_loop

[ "$TERRAFORMING_STATE" == "$PUSH_FLAG" ] && terraform_state_push_remote
