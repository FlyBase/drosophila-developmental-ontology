# Running the FBDV release pipeline
# 0. This command ensures process stops if any error encountered.
set -e

# 1. Preprocessing - not required for FBdv. To use this, copy code for pre_release from FBcv.Makefile
#sh run.sh make pre_release -B

# 2. Proper release.
sh run.sh make prepare_release -B
# To use auto-generated definitions, copy pre_release code from FBcv and use
#sh run.sh make SRC=fbdv-edit-release.owl IMP=false PAT=false prepare_release -B

