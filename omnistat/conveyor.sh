#!/bin/bash
#SBATCH -A <>
#SBATCH -J bale_ig
#SBATCH -t 02:00:00
#SBATCH -p batch
#SBATCH --ntasks-per-node=64
#SBATCH -S 0
#SBATCH --exclusive
#SBATCH -N 2
NODES=2
SS=$((1000000*64))

SIZE=$((SS*NODES))
export SHMEM_SYMMETRIC_SIZE=4G

cd $SLURM_SUBMIT_DIR
source oshmem-slurm.sh

ml use /sw/frontier/amdsw/modulefiles
ml omnistat/1.10.0

module use /sw/frontier/amdsw/modulefiles
module load omnistat-wrapper

export OMNISTAT_CONFIG=${HOME}/omnistat.custom
export OMNISTAT_VICTORIA_DATADIR=/lustre/orion/csc607/scratch/shubh/${SLURM_JOB_ID}

cd /lustre/orion/csc607/scratch/shubh/
mkdir data_${SLURM_JOB_ID}
cd data_${SLURM_JOB_ID}

${OMNISTAT_WRAPPER} usermode --start --interval 0.01

EXE=$HOME/distributed-lsb/shmem/shmem_lsbsort
#EXE=$HOME/distributed-lsb/shmem/shmem_lsbsort_convey
echo $EXE
echo $SS
echo $NODES
srun -N $NODES -n $((NODES*64)) $EXE --n $SIZE

${OMNISTAT_WRAPPER} usermode --stopexporters
${OMNISTAT_WRAPPER} query --job ${SLURM_JOB_ID} --interval 0.01 --export export-data
${OMNISTAT_WRAPPER} usermode --stopserver

rm -rf /lustre/orion/csc607/scratch/shubh/${SLURM_JOB_ID}

cd $SLURM_SUBMIT_DIR
module purge && module reset
source oshmem-slurm.sh
module load python
python3 -m pip install --user --no-index --find-links $HOME/wheels pandas
python3 network-extract.py /lustre/orion/csc607/scratch/shubh/data_${SLURM_JOB_ID}/export-data/omnistat-cxi.csv ${NODES}
rm -rf /lustre/orion/csc607/scratch/shubh/data_${SLURM_JOB_ID}