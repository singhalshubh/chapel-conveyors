#!/bin/bash
#SBATCH -A <>
#SBATCH -J chapel_ig
#SBATCH -t 02:00:00
#SBATCH -p batch
#SBATCH -S 0
#SBATCH --exclusive
#SBATCH -N 32
NODES=32
SS=$((1000000*64))

SIZE=$((SS*NODES))

export CHPL_LAUNCHER_USE_SBATCH=1
export CHPL_RT_USE_HUGEPAGES=yes
export CHPL_RT_LOCALES_PER_NODE=4
export CHPL_RT_MAX_HEAP_SIZE="50%"
export CHPL_LAUNCHER_MEM=unset
CHPL_RT_COMM_OFI_DEDICATED_AMH_CORES=true

module load PrgEnv-gnu
module load cray-python
module load papi
cd chapel/
source util/setchplenv.bash

#######################################
ml use /sw/frontier/amdsw/modulefiles
ml omnistat/1.10.0

module use /sw/frontier/amdsw/modulefiles
module load omnistat-wrapper

export OMNISTAT_CONFIG=${HOME}/omnistat.custom

export OMNISTAT_VICTORIA_DATADIR=/lustre/orion/csc607/scratch/shubh/${SLURM_JOB_ID}

cd /lustre/orion/csc607/scratch/shubh/
mkdir data_${SLURM_JOB_ID}
cd data_${SLURM_JOB_ID}

${OMNISTAT_WRAPPER} usermode --start --interval 0.1
####################################### (exe)

#EXE=$HOME/distributed-lsb/chpl/arkouda-radix-sort-strided-counts_real
EXE=$HOME/distributed-lsb/chpl/arkouda-radix-sort_real
#EXE=$HOME/distributed-lsb/chpl/arkouda-radix-sort-strided-counts-no-agg_real

echo $EXE
echo $SS
echo $NODES
srun -N ${NODES} -n $((4*NODES)) -c 16 --cpu-bind=none --exclusive $EXE -nl ${NODES}x4numa --n=${SIZE}

#######################################
${OMNISTAT_WRAPPER} usermode --stopexporters
${OMNISTAT_WRAPPER} query --job ${SLURM_JOB_ID} --interval 0.1 --export export-data
${OMNISTAT_WRAPPER} usermode --stopserver

rm -rf /lustre/orion/csc607/scratch/shubh/${SLURM_JOB_ID}

cd $SLURM_SUBMIT_DIR
module purge && module reset
source oshmem-slurm.sh
module load python
python3 -m pip install --user --no-index --find-links $HOME/wheels pandas
python3 network-extract.py /lustre/orion/csc607/scratch/shubh/data_${SLURM_JOB_ID}/export-data/omnistat-cxi.csv ${NODES}
rm -rf /lustre/orion/csc607/scratch/shubh/data_${SLURM_JOB_ID}
#######################################

# cd ../histogram/
# srun -N ${NODES} -n $((4*NODES)) -c 16 --cpu-bind=none --exclusive ./histo-atomics_real -nl ${NODES}x4numa --N=${N} --M=${N} --mode=ordered

# chpl histo.chpl --fast -suseBlockArr=true
# chpl histo-atomics.chpl --fast -M ../aggregation