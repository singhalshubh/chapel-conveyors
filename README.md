## Introduction
This repository contains the `chapel` and `conveyors` installation and execution on Frontier@ORNL for radix sort and index gather benchmarks. We conduct weak scaling experiments for nodes=[1...256] with 64 cores per node and 8GB per node on 100GB/s network bandwidth Slingshot. We attempt this research in spirit of exploring energy efficiency of Chapel (auto-aggregated mode) relative to Conveyors and AGP OpenSHMEM. 
Dated, Feb 9th 2026 EST.

## Team (GT + ORNL + LANL + HPE)
Georgia Institute of Technology: 
`Shubhendra Pal Singhal, Akihiro Hayashi, Vivek Sarkar`

Oak Ridge National Laboratory:
`Aaron Welch, Oscar Hernandez`

Los Alamos National Laboratory:
`Steve Poole`

Hewlett Packard Enterprise, USA :
`Nathan Wichmann, Bradford L. Chamberlain`

## Directory Structure
```
.
├── bale_block
│   ├── ig_block
│   ├── ig_block.cpp
│   ├── ig_cyclic
│   ├── ig_cyclic.cpp
│   ├── Makefile
│   ├── README.md
│   └── run.sh
├── index-gather
│   ├── chapel-frontier.tar.gz
│   ├── ig_energy.chpl
│   ├── ig_src_comm_matrix.chpl
│   ├── README.md
│   ├── run_bale.sh (run bale)
│   └── run_chapel.sh (run chapel)
├── radix-sort
│   ├── arkouda-radix-sort-strided-counts.chpl
│   ├── README.md
│   ├── shmem_lsbsort_convey.cpp
│   └── shmem_lsbsort.cpp
└── README.md

3 directories, 18 files
```

## Experimentation
Refer to https://docs.olcf.ornl.gov/systems/frontier_user_guide.html for description of HPC-supercomputer named Frontier@ORNL.

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

### Chapel Environment
```
shubh@login08:~/chapel> $CHPL_HOME/util/printchplenv
machine info: Linux login08 6.4.0-150600.23.47_15.0.10-cray_shasta_c #1 SMP Mon Apr 28 14:04:47 UTC 2025 (fd865db) x86_64
CHPL_HOME: /ccs/home/shubh/chapel *
script location: /autofs/nccs-svm1_home2/shubh/chapel/util/chplenv
CHPL_TARGET_PLATFORM: hpe-cray-ex
CHPL_TARGET_COMPILER: llvm
CHPL_TARGET_ARCH: x86_64
CHPL_TARGET_CPU: x86-trento
CHPL_LOCALE_MODEL: flat *
CHPL_COMM: ofi *
  CHPL_LIBFABRIC: system
  CHPL_COMM_OFI_OOB: pmi2
CHPL_TASKS: qthreads
CHPL_LAUNCHER: slurm-srun *
CHPL_TIMERS: generic
CHPL_UNWIND: none
CHPL_TARGET_MEM: jemalloc
CHPL_ATOMICS: cstdlib
  CHPL_NETWORK_ATOMICS: ofi
CHPL_GMP: bundled
CHPL_HWLOC: bundled
CHPL_RE2: bundled
CHPL_LLVM: bundled *
CHPL_AUX_FILESYS: none
```

And we investigate
https://github.com/chapel-lang/chapel/blob/main/modules/packages/CopyAggregation.chpl
```
defaultBuffSize = 8192
yieldFrequency = 1024
When the destination is always local and the source may be remote, a :record:`SrcAggregator` should be used.
```

### Installation of BALE

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

## Contributors
Lead: Shubhendra Pal Singhal (ssinghal74@gatech.edu), Habanero Labs, USA
> Credits to Dr. Akihiro Hayashi (ahayashi@gatech.edu) for finding the benchmarks.

> Credits to ORNL GRO internship with Dr. Oscar Hernandez (oscar@ornl.gov) and funding support for Frontier machine access.

> Credits to Dr. Wael Elwasif (elwasifwr@ornl.gov) for guiding us on Chapel installation on Frontier.

> Special thanks to HPE for supporting this work and helping us throughout with Chapel's best possible executions. Thanks to Dr. Bradford, and Dr. Nathan. 

