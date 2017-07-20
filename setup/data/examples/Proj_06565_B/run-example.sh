#!/bin/bash

prism_request_to_yaml.py \
	-m Proj_06565_B_sample_mapping.txt \
	-p Proj_06565_B_sample_pairing.txt \
	-g Proj_06565_B_sample_grouping.txt \
	-o . \
	-f inputs.yaml

nohup prism-runner.sh \
	-w project-workflow.cwl \
	-i inputs.yaml \
	-b lsf &

# prism_submit.py \
#     --id Proj_06565_B \
#     --path . \
#     --workflow project-workflow.cwl

