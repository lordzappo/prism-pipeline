#!/usr/bin/python
"""postprocess"""

import argparse
import ruamel.yaml


def read(filename):
    """return file contents"""

    with open(filename, 'r') as file_in:
        return file_in.read()


def write(filename, cwl):
    """write to file"""

    with open(filename, 'w') as file_out:
        file_out.write(cwl)


def main():
    """main function"""

    parser = argparse.ArgumentParser(description='postprocess')

    parser.add_argument(
        '-f',
        action="store",
        dest="filename_cwl",
        help='Name of the cwl file',
        required=True
    )

    params = parser.parse_args()

    cwl = ruamel.yaml.load(read(params.filename_cwl),
                           ruamel.yaml.RoundTripLoader)

    cwl['inputs']['input_file']['type'] = ruamel.yaml.load("""
- File
- type: array
  items: string
""", ruamel.yaml.RoundTripLoader)

    cwl['inputs']['out']['type'] = ruamel.yaml.load("""
- string
- type: array
  items: string
""", ruamel.yaml.RoundTripLoader)

    cwl['inputs']['minMappingQuality']['type'] = 'string'
    cwl['inputs']['minBaseQuality']['type'] = 'string'
    cwl['inputs']['intervals']['type'] = ['string', 'File']

    #-->
    # fixme: until we can auto generate cwl for GATK
    # set outputs using outputs.yaml
    import os
    cwl['outputs'] = ruamel.yaml.load(
        read(os.path.dirname(params.filename_cwl) + "/outputs.yaml"),
        ruamel.yaml.RoundTripLoader)['outputs']

    # from : ['cmo_gatk', '-T DepthOfCoverage', '--version 3.3-0']
    # to   : ['cmo_gatk', '-T', 'DepthOfCoverage', '--version', '3.3-0']
    cwl['baseCommand'] = ['cmo_gatk', '-T', 'DepthOfCoverage', '--version', '3.3-0']
    #<--

    write(params.filename_cwl, ruamel.yaml.dump(
        cwl, Dumper=ruamel.yaml.RoundTripDumper))


if __name__ == "__main__":

    main()
