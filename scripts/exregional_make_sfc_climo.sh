#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions script and the function definitions
# file.
#
#-----------------------------------------------------------------------
#
. $SCRIPT_VAR_DEFNS_FP
. $USHDIR/source_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1

script_name=$( basename "$0" )
print_info_msg "\
========================================================================
Entering script:  \"${script_name}\"
This script will generate surface fields on the FV3 native grid based on
climatology.
========================================================================\n"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( "WORKDIR_LOCAL" )
process_args valid_args "$@"

# If VERBOSE is set to TRUE, print out what each valid argument has been
# set to.
if [ "$VERBOSE" = "TRUE" ]; then
  num_valid_args="${#valid_args[@]}"
  for (( i=0; i<$num_valid_args; i++ )); do
    declare -p "${valid_args[$i]}"
  done
fi
#
#-----------------------------------------------------------------------
#
# Are these machine dependent??
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
ulimit -a
#
#-----------------------------------------------------------------------
#
# Change location to the temporary directory.
#
#-----------------------------------------------------------------------
#
cd_vrfy ${WORKDIR_LOCAL}
#
#-----------------------------------------------------------------------
#
# Set the tile number(s).  The stand-alone regional and global nest are 
# assumed to be tile 7.
#
#-----------------------------------------------------------------------
#
if [[ "$gtype" == "nest" ]] || [[ "$gtype" == "regional" ]]; then
  tiles=("7")
else
  tiles=("1" "2" "3" "4" "5" "6")
fi

prefix="\"${CRES}_oro_data.tile"
#prefix="\"${CRES}.oro_data.tile"
orog_fns=( "${tiles[@]/#/$prefix}" )
suffix=".nc\""
orog_fns=( "${orog_fns[@]/%/$suffix}" )
#
#-----------------------------------------------------------------------
#
# Create the namelist that the sfc_climo_gen code will read in.
#
# Question: Should this instead be created from a template file?
#
#-----------------------------------------------------------------------
#
mosaic_file="${WORKDIR_GRID}/${CRES}_mosaic.nc"

cat << EOF > ./fort.41
&config
input_facsf_file="${SFC_CLIMO_INPUT_DIR}/facsf.1.0.nc"
input_substrate_temperature_file="${SFC_CLIMO_INPUT_DIR}/substrate_temperature.2.6x1.5.nc"
input_maximum_snow_albedo_file="${SFC_CLIMO_INPUT_DIR}/maximum_snow_albedo.0.05.nc"
input_snowfree_albedo_file="${SFC_CLIMO_INPUT_DIR}/snowfree_albedo.4comp.0.05.nc"
input_slope_type_file="${SFC_CLIMO_INPUT_DIR}/slope_type.1.0.nc"
input_soil_type_file="${SFC_CLIMO_INPUT_DIR}/soil_type.statsgo.0.05.nc"
input_vegetation_type_file="${SFC_CLIMO_INPUT_DIR}/vegetation_type.igbp.0.05.nc"
input_vegetation_greenness_file="${SFC_CLIMO_INPUT_DIR}/vegetation_greenness.0.144.nc"
mosaic_file_mdl="${mosaic_file}"
orog_dir_mdl="${WORKDIR_SHVE}"
orog_files_mdl=${orog_fns}
halo=${nh4_T7}
maximum_snow_albedo_method="bilinear"
snowfree_albedo_method="bilinear"
vegetation_greenness_method="bilinear"
/
EOF
#
#-----------------------------------------------------------------------
#
# Set the run machine-dependent run command.
#
#-----------------------------------------------------------------------
#
case $MACHINE in

"WCOSS_C")
# This could be wrong.  Just a guess since I don't have access to this machine.
  APRUN_SFC=${APRUN_SFC:-"aprun -j 1 -n 6 -N 6"}
  ;;

"WCOSS")
# This could be wrong.  Just a guess since I don't have access to this machine.
  APRUN_SFC=${APRUN_SFC:-"aprun -j 1 -n 6 -N 6"}
  ;;

"THEIA")
# Need to load intel/15.1.133.  This and all other module loads should go into a module file.
module load intel/15.1.133
module list
  APRUN_SFC="mpirun -np ${SLURM_NTASKS}"
  ;;

*)
  print_err_msg_exit "${script_name}" "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN_SFC = \"$APRUN_SFC\""
  ;;

esac
#
#-----------------------------------------------------------------------
#
# Run the code.
#
#-----------------------------------------------------------------------
#
$APRUN_SFC ${EXECDIR}/sfc_climo_gen || print_err_msg_exit "${script_name}" "\
Call to executable that generates surface climatology files returned 
with nonzero exit code."
#
#-----------------------------------------------------------------------
#
# Move output files out of the temporary directory.
#
#-----------------------------------------------------------------------
#
case "$gtype" in

#
# Consider, global, stetched, and nested grids.
#
"global" | "stretch" | "nested")
#
# Move all files ending with ".nc" to the WORKDIR_SFC_CLIMO directory.
# In the process, rename them so that the file names start with the C-
# resolution (followed by an underscore).
#
  for fn in *.nc; do
    if [[ -f $fn ]]; then
      mv_vrfy $fn ${WORKDIR_SFC_CLIMO}/${CRES}_${fn}
    fi
  done
  ;;

#
# Consider regional grids.
#
"regional")
#
# Move all files ending with ".halo.nc" (which are the files for a grid
# that includes the specified non-zero-width halo) to the WORKDIR_SFC_-
# CLIMO directory.  In the process, rename them so that the file names
# start with the C-resolution (followed by a dot) and contain the (non-
# zero) halo width (in units of number of grid cells).
#
  for fn in *.halo.nc; do
    if [[ -f $fn ]]; then
      bn="${fn%.halo.nc}"
      mv_vrfy $fn ${WORKDIR_SFC_CLIMO}/${CRES}.${bn}.halo${nh4_T7}.nc
    fi
  done
#
# Move all remaining files ending with ".nc" (which are the files for a
# grid that doesn't include a halo) to the WORKDIR_SFC_CLIMO directory.  
# In the process, rename them so that the file names start with the C-
# resolution (followed by a dot) and contain the string "halo0" to indi-
# cate that the grids in these files do not contain a halo.
#
  for fn in *.nc; do
    if [[ -f $fn ]]; then
      bn="${fn%.nc}"
      mv_vrfy $fn ${WORKDIR_SFC_CLIMO}/${CRES}.${bn}.halo${nh0_T7}.nc
    fi
  done
  ;;

esac
#
#-----------------------------------------------------------------------
#
# Can these be moved to stage_static if this script is called before
# stage_static.sh????
# These have been moved.  Can delete the following after testing.
#
#-----------------------------------------------------------------------
#
#cd_vrfy ${WORKDIR_SFC_CLIMO}
#
#suffix=".halo${nh4_T7}.nc"
#for fn in *${suffix}; do
#  bn="${fn%.halo${nh4_T7}.nc}"
#  ln_vrfy -fs ${bn}${suffix} ${bn}.nc
#done
#
#-----------------------------------------------------------------------
#
# GSK 20190430:
# This is to make rocoto aware that the make_sfc_climo task has completed
# (so that other tasks can be launched).  This should be done through 
# rocoto's dependencies, but not sure how to do it yet.
#
#-----------------------------------------------------------------------
#
cd_vrfy $EXPTDIR
touch "make_sfc_climo_files_task_complete.txt"
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "\n\
========================================================================
All surface climatology files generated successfully!!!
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1