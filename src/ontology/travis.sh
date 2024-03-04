# Running the DPO release pipeline for TRAVIS (no import or pattern updates)
set -e

sh run.sh make MIR=false IMP=false PAT=false prepare_release -B

