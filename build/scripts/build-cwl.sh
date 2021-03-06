#!/bin/bash

# load build-related settings
source ./settings-build.sh

# load utils
source ./tools-utils.sh


usage()
{
cat << EOF

USAGE: $0 [options]

OPTIONS:

   -t      List of tools to build (comma-separated list)
           All pre-defined tools will be built if -t is not specified.

           Example: $0 -t bwa:0.7.12:cmo_bwa_mem,trimgalore:0.4.3:cmo_trimgalore

   -z      Show list of tools that be built

   -h      Help

EOF
}

while getopts “t:zh” OPTION
do
    case $OPTION in
        t) SELECTED_TOOLS_TO_BUILD=$OPTARG ;;
        z) for tool in $(get_tools_name_version_cmo); do echo $tool; done; exit 1 ;;
        h) usage; exit 1 ;;
        *) usage; exit 1 ;;
    esac
done

# comma-separated list of [tool-name]:[tool-version]:[corresponding-cmo-wrapper]
if [ -z "$SELECTED_TOOLS_TO_BUILD" ]
then
    SELECTED_TOOLS_TO_BUILD=$(get_tools_name_version_cmo)
fi

# assume no error
error_flag=0

for tool_info in $(echo $SELECTED_TOOLS_TO_BUILD | sed "s/,/ /g")
do
    tool_name=$(get_tool_name $tool_info)
    tool_version=$(get_tool_version $tool_info)
    cmo_wrapper=$(get_cmo_wrapper_name $tool_info)

    echo "Generating CWL: ${cmo_wrapper} (${tool_name} version ${tool_version})"

    error_file_name="error.${cmo_wrapper}-${tool_version}.txt"
    ./process-cwl.sh -t ${tool_name} -v ${tool_version} -c ${cmo_wrapper} 2>${error_file_name}

    if [ $? -eq 0 ]
    then
        # no error found, remove the empty file
        rm -rf ${error_file_name}
    else
        # set error flag to 1
        error_flag=1
    fi

done

if [ $error_flag -eq 1 ]
then
    echo "Error(s) occurred - please check error.*.txt for more information."
    exit 1
else
    exit 0
fi
