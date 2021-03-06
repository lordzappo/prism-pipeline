#!/bin/bash

pipeline_name_version="variant/1.3.1"

roslin-runner.sh \
    -v ${pipeline_name_version} \
    -w samtools/1.3.1/samtools-sam2bam.cwl \
    -i inputs.yaml \
    -b lsf
