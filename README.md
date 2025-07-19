## Introduction
This repository contains the `chapel` and `conveyors` installation and execution on Frontier@ORNL. We conduct weak scaling experiments for nodes=$[1...2048]$ with $64$ processes per node and $8$ GB per node. We attempt this research in spirit of validating Chapel (2022-2025) results showcased, where Chapel auto-aggregated mode serves better performance than Conveyors. 
This work is dated July 2025.

## Team (GT+ORNL)
Shubhendra Pal Singhal, Akihiro Hayashi, Oscar Hernandez, Vivek Sarkar

## Goals of the project
- We use Index Gather, as rest of applications - Histogram and Topological Sort are reported to be slower than Conveyors.
- Identify the performance in execution time for Chapel vs Conveyors on scale. 
- Reason this performance different using a mathematical model, and diving in memory and network utlization. We shall ignore the visions/success of programming models out of scope, and solely focus on raw performance numbers.

## Directory Structure
```
.
├── chapel-frontier.tar.gz (contains execution of chapel IG)
└── README.md
0 directories, 2 files
```

## Experimentation
Refer to https://docs.olcf.ornl.gov/systems/frontier_user_guide.html for description of HPC-supercomputer named Frontier.

### Installation of Chapel
> We use `ofi` for setup.

`setup_chapel.sh`
```
if [ ! -d chapel ]; then
    git clone https://github.com/chapel-lang/chapel/
fi

cd chapel/
source util/setchplenv.bash
module unload $(module -t list 2>&1 | grep PrgEnv-)
module unload rocm
module unload craype-accel-amd-gfx90a
module load PrgEnv-gnu
module load cray-python

export CHPL_LLVM=bundled
export CHPL_COMM=ofi
export CHPL_LOCALE_MODEL=flat
export CHPL_GPU=none
unset CHPL_GPU_ARCH
unset CHPLENV_GPU_REQ_ERRS_AS_WARNINGS

export CHPL_LAUNCHER=slurm-srun
export CHPL_RT_MAX_HEAP_SIZE="50%"
export CHPL_LAUNCHER_MEM=unset
export CHPL_LAUNCHER_CORES_PER_LOCALE=64

export CHPL_LAUNCHER_ACCOUNT=csc607
export CHPL_LAUNCHER_WALLTIME=2:00:00
export CHPL_LAUNCHER_USE_SBATCH=1

make clean
make -j20

cd test/studies/bale/aggregation/
chpl ig.chpl --fast -suseBlockArr=true
```

### Execution for Chapel

`run_chapel.sh`
```
#!/bin/bash
#SBATCH -A csc607
#SBATCH -J chapel_ig
#SBATCH -t 0:40:00
#SBATCH -p batch
#SBATCH -S 0
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=64

export CHPL_LAUNCHER_ACCOUNT=csc607
export CHPL_LAUNCHER_WALLTIME=0:40:00
export CHPL_LAUNCHER_USE_SBATCH=1
export CHPL_LAUNCHER_QUEUE=batch
export CHPL_LAUNCHER_CPUS_PER_CU=64

export CHPL_LAUNCHER=slurm-srun
export CHPL_RT_MAX_HEAP_SIZE="50%"
export CHPL_LAUNCHER_MEM=unset
export CHPL_LAUNCHER_CORES_PER_LOCALE=64

export CHPL_LLVM=bundled
export CHPL_COMM=ofi
export CHPL_LOCALE_MODEL=flat
export CHPL_GPU=none

cd chapel/
source util/setchplenv.bash
cd test/studies/bale/aggregation/

srun -n ${NODES} ./ig_real -nl ${NODES} --N=${N} --M=${M}
```

`submit_chapel.sh`
```
#!/bin/bash

SIZES=(1000000 10000000 100000000)
MSIZES=(1000000 10000000 100000000)
NODES_LIST=(1 2 4 8 16 32 64 128 256 512 1024 2048)

for N in "${SIZES[@]}"; do
  for M in "${MSIZES[@]}"; do
    for NODES in "${NODES_LIST[@]}"; do
      export NODES N M
      export SBATCH_EXPORT=ALL
      sbatch --ntasks=$NODES -o output_chapel_M${M}_N${N}_nodes${NODES} --export=NODES=$NODES,M=$M,N=$N run_chapel.sh
    done
  done
done

```

### Installation of Conveyors

`setup_bale.sh`
```
module use /ccs/proj/csc607/cray-openshmemx/modulefiles
module purge
module load PrgEnv-cray/8.3.3
module load craype-x86-trento
module load cray-openshmemx/11.7.2.3
module load cray-pmi
module load cray-mrnet
module load xpmem
module load cray-python/3.10.10
module load valgrind4hpc
module unload darshan-runtime
module unload hsi
module unload DefApps
module unload cray-libsci
module load cray-fix

PROJ_DIR=/ccs/proj/csc607
export PLATFORM=cray

if [ ! -d bale ]; then
    git clone https://github.com/jdevinney/bale.git
    cd bale/src/bale_classic/
    ./bootstrap.sh
    nice python3 make_bale --shmem --config_opts "CC=cc ac_cv_search_shmemx_team_alltoallv=no" -j
    cd ../../..
fi

export BALE_INSTALL=$PWD/bale/src/bale_classic/build_cray
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$BALE_INSTALL/lib
```

### Execution for Conveyors

`submit_bale.sh`
```
#!/bin/bash

SIZES=(1000000 10000000 100000000)
TSIZES=(1000000 10000000 100000000)
NODES_LIST=(1 2 4 8 16 32 64 128 256 512 1024 2048)

for N in "${SIZES[@]}"; do
  for T in "${TSIZES[@]}"; do
    for NODES in "${NODES_LIST[@]}"; do
      export N T
      export SBATCH_EXPORT=ALL
      sbatch --ntasks=$NODES --export=ALL,N=$N,T=$T,NODES=$NODES run_bale.sh
    done
  done
done
```

`run_bale.sh`
```
#!/bin/bash
#SBATCH -A csc607
#SBATCH -J bale_histo
#SBATCH -o output
#SBATCH -t 10:40:00
#SBATCH -p batch
#SBATCH --ntasks-per-node=64
#SBATCH --exclusive
#SBATCH -S 0

srun -N $NODES -n $(($NODES*64)) ./bale/src/bale_classic/build_cray/bin/ig -n $N -T $T &> out_bale_N${N}_T${T}_nodes_${NODES}
```

## Contributors
Shubhendra Pal Singhal (ssinghal74@gatech.edu), Habanero Labs, USA
> Credits to Dr. Akihiro Hayashi (ahayashi@gatech.edu) for finding the performance reportings of Chapel.

> Credits to ORNL GRO internship with Dr. Oscar Hernandez (oscar@ornl.gov) and funding support for Frontier machine access.

> Credits to Dr. Wael Elwasif (elwasifwr@ornl.gov) for guiding us on Chapel installation on Frontier.

