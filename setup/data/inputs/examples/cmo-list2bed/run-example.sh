#!/bin/bash

prism-runner.sh \
    -w cmo-list2bed/1.0.0/cmo-list2bed.cwl \
    -i inputs.yaml \
    -b lsf
