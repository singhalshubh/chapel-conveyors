This repository contains the `chapel` and `conveyors` installation and execution on Frontier (ORNL). We conduct weak scaling experiments for nodes=[1...256] with 64 processes per node and 8GB per node. We attempt this research in spirit of validating Chapel-2025 (since 2022) results showcased, where Chapel auto-aggregated mode serves better performance than Conveyors. 

## Directory Structure
.
├── chapel-frontier.tar.gz (contains execution of chapel IG)
└── README.md

0 directories, 2 files

## Installation of Chapel on Frontier
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

## Running chapel on frontier

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

# List of problem sizes in elements (1M to 100M)
SIZES=(1000000 10000000 100000000)
# List of buffer sizes (used as -T flag)
MSIZES=(1000000 10000000 100000000)
# Max nodes to test with
NODES_LIST=(1 2 4 8 16 32 64 128 256)

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

## Installation and Execution of Bale

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

`submit_bale.sh`
```
#!/bin/bash

# List of problem sizes in elements (1M to 100M)
SIZES=(1000000 10000000)
# List of buffer sizes (used as -T flag)
TSIZES=(1000000 10000000 100000000)

for N in "${SIZES[@]}"; do
  for T in "${TSIZES[@]}"; do
    export N T
    export SBATCH_EXPORT=ALL
    sbatch --export=ALL,N=$N,T=$T run_bale.sh
  done
done
```