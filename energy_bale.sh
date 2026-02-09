#!/bin/bash
#SBATCH -A <>
#SBATCH -J bale_ig
#SBATCH -t 00:30:00
#SBATCH -p batch
#SBATCH --ntasks-per-node=64
#SBATCH -S 0
#SBATCH --exclusive
#SBATCH -N 64

NODES=64

cd $SLURM_SUBMIT_DIR
source oshmem-slurm.sh
cd bale/src/bale_classic/build_cray/apps
module load papi

M=10000000

srun -N $NODES -n $((NODES*64)) ./ig -n $M -T $M -M 1
srun -N $NODES -n $((NODES*64)) ./ig -n $M -T $M -M 8