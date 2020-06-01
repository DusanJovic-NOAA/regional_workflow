#!/bin/bash

module purge
module load intel/19.0.5.281 impi netcdf hdf5
module list

make -f Makefile_hera
