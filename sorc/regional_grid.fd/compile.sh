#!/bin/bash

module purge
module load intel/18.0.5.274 impi/2018.0.4 netcdf/4.7.0 hdf5/1.10.5
module list

make -f Makefile_hera
