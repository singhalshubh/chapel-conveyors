#!/bin/bash
#SBATCH -A <>
#SBATCH -J chapel_ig
#SBATCH -t 0:40:00
#SBATCH -p batch
#SBATCH -S 0
#SBATCH --exclusive
#SBATCH -N 64

NODES=64

export CHPL_LAUNCHER_USE_SBATCH=1
export CHPL_RT_USE_HUGEPAGES=yes
export CHPL_RT_LOCALES_PER_NODE=4
export CHPL_RT_MAX_HEAP_SIZE="50%"
export CHPL_LAUNCHER_MEM=unset

module load PrgEnv-gnu
module load cray-python
module load papi
# module load craype-hugepages16M
# export CHPL_RT_USE_HUGEPAGES=yes

cd chapel/
source util/setchplenv.bash
cd test/studies/bale/aggregation/

#$CHPL_HOME/util/printchplenv --all
# export CHPL_AGGREGATION_DST_BUFF_SIZE=${BUF}
# export CHPL_AGGREGATION_SRC_BUFF_SIZE=${BUF}

SIZES=(1000000)
MSIZES=(1000000)

for N in "${SIZES[@]}"; do
  for M in "${MSIZES[@]}"; do
      echo "N=" $N "T=" $M $NODES
      srun -N ${NODES} -n $((4*NODES)) -c 16 --cpu-bind=none --exclusive ./ig_real -nl ${NODES}x4numa --N=${N} --M=${M}
  done
done