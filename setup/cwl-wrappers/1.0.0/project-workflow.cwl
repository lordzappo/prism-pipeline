#!/usr/bin/env cwl-runner

$namespaces:
  dct: http://purl.org/dc/terms/
  foaf: http://xmlns.com/foaf/0.1/
  doap: http://usefulinc.com/ns/doap#

$schemas:
- http://dublincore.org/2012/06/14/dcterms.rdf
- http://xmlns.com/foaf/spec/20140114.rdf
- http://usefulinc.com/ns/doap#

doap:release:
- class: doap:Version
  doap:name: project-workflow
  doap:revision: 1.0.0
- class: doap:Version
  doap:name: cwl-wrapper
  doap:revision: 1.0.0

dct:creator:
- class: foaf:Organization
  foaf:name: Memorial Sloan Kettering Cancer Center
  foaf:member:
  - class: foaf:Person
    foaf:name: Christopher Harris
    foaf:mbox: mailto:harrisc2@mskcc.org

dct:contributor:
- class: foaf:Organization
  foaf:name: Memorial Sloan Kettering Cancer Center
  foaf:member:
  - class: foaf:Person
    foaf:name: Christopher Harris
    foaf:mbox: mailto:harrisc2@mskcc.org
  - class: foaf:Person
    foaf:name: Jaeyoung Chun
    foaf:mbox: mailto:chunj@mskcc.org

cwlVersion: v1.0

class: Workflow
requirements:
  MultipleInputFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  SubworkflowFeatureRequirement: {}
  InlineJavascriptRequirement: {}

inputs:
  db_files:
    type:
      type: record
      fields:
        hapmap:
          type: File
          secondaryFiles:
            - .idx
        dbsnp:
          type: File
          secondaryFiles:
            - .idx
        indels_1000g:
          type: File
          secondaryFiles:
            - .idx
        snps_1000g:
          type: File
          secondaryFiles:
            - .idx
        cosmic:
          type: File
          secondaryFiles:
            - .idx
        refseq: File
        ref_fasta: string
        vep_data: string
        exac_filter:
          type: File
          secondaryFiles:
            - .tbi
        hotspot_list: File
        curated_bams:
          type:
            type: array
            items: File
          secondaryFiles:
              - ^.bai
        ffpe_normal_bams:
          type:
            type: array
            items: File
          secondaryFiles:
              - ^.bai

  groups:
    type:
      type: array
      items:
        type: array
        items: string
  runparams:
    type:
      type: record
      fields:
        abra_scratch: string
        covariates:
          type:
            type: array
            items: string
        emit_original_quals: boolean
        genome: string
        mutect_dcov: int
        mutect_rf:
          type:
            type: array
            items: string
        num_cpu_threads_per_data_thread: int
        num_threads: int
        tmp_dir: string
  samples:
    type:
      type: array
      items:
        type: record
        fields:
          CN: string
          LB: string
          ID: string
          PL: string
          PU: string
          R1:
            type:
              type: array
              items: File
          R2:
            type:
              type: array
              items: File
          RG_ID: string
          adapter: string
          adapter2: string
          bwa_output: string
  pairs:
    type:
      type: array
      items:
        type: array
        items: string

outputs:
  bams:
    type:
      type: array
      items: File
    secondaryFiles:
      - ^.bai
    outputSource: group_process/bams
  clstats1:
    type:
      type: array
      items: File
    outputSource: group_process/clstats1
  clstats2:
    type:
      type: array
      items: File
    outputSource: group_process/clstats2
  md_metrics:
    type:
      type: array
      items: File
    outputSource: group_process/md_metrics
  mutect_vcf:
    type:
      type: array
      items: File
    outputSource: variant_calling/mutect_vcf
  mutect_callstats:
    type:
      type: array
      items: File
    outputSource: variant_calling/mutect_callstats
  vardict_vcf:
    type:
      type: array
      items: File
    outputSource: variant_calling/vardict_vcf
  pindel_vcf:
    type:
      type: array
      items: File
    outputSource: variant_calling/pindel_vcf

steps:
  projparse:
    run: parse-project-yaml-input/1.0.0/parse-project-yaml-input.cwl
    in:
      db_files: db_files
      groups: groups
      pairs: pairs
      samples: samples
      runparams: runparams
    out: [R1, R2, adapter, adapter2, bwa_output, LB, PL, RG_ID, PU, ID, CN, genome, tmp_dir, abra_scratch, cosmic, covariates, dbsnp, hapmap, indels_1000g, mutect_dcov, mutect_rf, refseq, snps_1000g, ref_fasta, exac_filter, vep_data, curated_bams, ffpe_normal_bams, hotspot_list]
  group_process:
    run:  module-1-2.chunk.cwl
    in:
      fastq1: projparse/R1
      fastq2: projparse/R2
      adapter: projparse/adapter
      adapter2: projparse/adapter2
      bwa_output: projparse/bwa_output
      add_rg_LB: projparse/LB
      add_rg_PL: projparse/PL
      add_rg_ID: projparse/RG_ID
      add_rg_PU: projparse/PU
      add_rg_SM: projparse/ID
      add_rg_CN: projparse/CN
      tmp_dir: projparse/tmp_dir
      hapmap: projparse/hapmap
      dbsnp: projparse/dbsnp
      indels_1000g: projparse/indels_1000g
      cosmic: projparse/cosmic
      snps_1000g: projparse/snps_1000g
      genome: projparse/genome
      mutect_dcov: projparse/mutect_dcov
      mutect_rf: projparse/mutect_rf
      covariates: projparse/covariates
      abra_scratch: projparse/abra_scratch
      refseq: projparse/refseq
    out: [clstats1, clstats2, bams, md_metrics, covint_bed, covint_list]
    scatter: [fastq1,fastq2,adapter,adapter2,bwa_output,add_rg_LB,add_rg_PL,add_rg_ID,add_rg_PU,add_rg_SM,add_rg_CN, tmp_dir, genome, abra_scratch, dbsnp, hapmap, indels_1000g, cosmic, snps_1000g, mutect_dcov, mutect_rf, abra_scratch, refseq, covariates]
    scatterMethod: dotproduct
  pairing:
    run: sort-bams-by-pair/1.0.0/sort-bams-by-pair.cwl
    in:
      bams: group_process/bams
      pairs: pairs
      db_files: db_files
      runparams: runparams
      beds: group_process/covint_bed
    out: [tumor_bams, normal_bams, tumor_sample_ids, normal_sample_ids, dbsnp, cosmic, mutect_dcov, mutect_rf, refseq, genome, covint_bed]
  variant_calling:
    run: module-3.cwl
    in:
      tumor_bam: pairing/tumor_bams
      normal_bam: pairing/normal_bams
      genome: pairing/genome
      bed: pairing/covint_bed
      normal_sample_id: pairing/normal_sample_ids
      tumor_sample_id: pairing/tumor_sample_ids
      dbsnp: pairing/dbsnp
      cosmic: pairing/cosmic
      mutect_dcov: pairing/mutect_dcov
      mutect_rf: pairing/mutect_rf
      refseq: pairing/refseq
    out: [mutect_vcf, mutect_callstats, vardict_vcf, pindel_vcf]
    scatter: [tumor_bam, normal_bam, normal_sample_id, tumor_sample_id, genome, dbsnp, cosmic, refseq, mutect_rf, mutect_dcov, bed]
    scatterMethod: dotproduct
  parse_pairs:
    run: parse-pairs-and-vcfs/1.0.0/parse-pairs-and-vcfs.cwl
    in:
      bams: group_process/bams
      pairs: pairs
      mutect_vcf: variant_calling/mutect_vcf
      mutect_callstats: variant_calling/mutect_callstats
      pindel_vcf: variant_calling/pindel_vcf
      vardict_vcf: variant_calling/vardict_vcf
      genome: projparse/genome
      exac_filter: projparse/exac_filter
      ref_fasta: projparse/ref_fasta
      vep_data: projparse/vep_data
      curated_bams: projparse/curated_bams
      ffpe_normal_bams: projparse/ffpe_normal_bams
      hotspot_list: projparse/hotspot_list

    out: [tumor_id, normal_id, srt_mutect_vcf, srt_mutect_callstats, srt_pindel_vcf, srt_vardict_vcf, srt_genome, srt_ref_fasta, srt_exac_filter, srt_vep_data, srt_bams, srt_curated_bams, srt_ffpe_normal_bams, srt_hotspot_list]
  filter:
    run: module-4.cwl
    in:
      bams: parse_pairs/srt_bams
      mutect_vcf: parse_pairs/srt_mutect_vcf
      mutect_callstats: parse_pairs/srt_mutect_callstats
      pindel_vcf: parse_pairs/srt_pindel_vcf
      vardict_vcf: parse_pairs/srt_vardict_vcf
      genome: parse_pairs/srt_genome
      ref_fasta: parse_pairs/srt_ref_fasta
      exac_filter: parse_pairs/srt_exac_filter
      vep_data: parse_pairs/srt_vep_data
      tumor_sample_name: parse_pairs/tumor_id
      normal_sample_name: parse_pairs/normal_id
      curated_bams: parse_pairs/srt_curated_bams
      ffpe_normal_bams: parse_pairs/srt_ffpe_normal_bams
      hotspot_list: parse_pairs/srt_hotspot_list
    out: [maf]
    scatter: [mutect_vcf, mutect_callstats, pindel_vcf, vardict_vcf, tumor_sample_name, normal_sample_name, ref_fasta, exac_filter, vep_data, genome]
    scatterMethod: dotproduct