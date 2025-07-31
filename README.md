## Introduction
This repository contains the `chapel` and `conveyors` installation and execution on Frontier@ORNL. We conduct weak scaling experiments for nodes=[1...2048] with 64 cores per node and 8GB per node on 100GB/s network bandwidth Slingshot. We attempt this research in spirit of validating Chapel (2022-2025) results showcased, where Chapel auto-aggregated mode serves better performance than Conveyors. 
This work is dated July 2025.

## Team (GT+ORNL)
Shubhendra Pal Singhal, Akihiro Hayashi, Oscar Hernandez, Vivek Sarkar

## Goals of the project
- We use Index Gather, as rest of applications - Histogram and Topological Sort are reported to be slower than Conveyors.
- Identify the performance in execution time for Chapel vs Conveyors on scale. 
- Reason this performance different using a mathematical model, and diving in memory and network utlization. We shall ignore the visions/success of programming models out of scope, and solely focus on raw performance numbers.

## Explanation of Chapel-IG

```
proc main() {
  const D = if useBlockArr then blockDist.createDomain(0..#tableSize)
                           else cyclicDist.createDomain(0..#tableSize);
  var A: [D] int = D;

  const UpdatesDom = blockDist.createDomain(0..#numUpdates);
  var Rindex: [UpdatesDom] int;

  fillRandom(Rindex, 208);
  Rindex = mod(Rindex, tableSize);
  var tmp: [UpdatesDom] int = -1;

  startTimer();
  forall (t, r) in zip (tmp, Rindex) with (var agg = new SrcAggregator(int)) {
    agg.copy(t, A[r]);
  }
  stopTimer("AGG");
}
```
- Input data is indices (Rindex) are generated at random [0, $N$ * num_locale * num_tasks/locale]. 
- Operation performed is copy the value of A[rindex] into local buffer `t`. Therefore, destination increments +1 for request after-which a PUT-->GET is issued to copy the value back. It uses `SrcAggregator` which implies `t` is on local locale and A[r] is on remote locale. 

`SrcAggregator.init operation`
```
proc ref postinit() {
      dstAddrs = allocate(c_ptr(aggType), numLocales);
      lSrcAddrs = allocate(c_ptr(aggType), numLocales);
      bufferIdxs = bufferIdxAlloc();
      for loc in myLocaleSpace {
        dstAddrs[loc] = allocate(aggType, bufferSize);
        lSrcAddrs[loc] = allocate(aggType, bufferSize);
        bufferIdxs[loc] = 0;
        rSrcAddrs[loc] = new remoteBuffer(aggType, bufferSize, loc);
        rSrcVals[loc] = new remoteBuffer(elemType, bufferSize, loc);
      }
    }
```
- SrcAggregator is initialised with a following set of buffers - `dstAddrs, lSrcAddrs` are local and are of size #num_locale*8192, whereas `rSrcAddrs, rSrcVals` are remote buffers allocated for same size. 

`SrcAggregator.copy operation`
```
    inline proc ref copy(ref dst: elemType, const ref src: elemType) {
      if verboseAggregation {
        writeln("SrcAggregator.copy is called");
      }
      if boundsChecking {
        assert(dst.locale.id == here.id);
      }
      const dstAddr = getAddr(dst);

      const loc = src.locale.id;
      lastLocale = loc;
      const srcAddr = getAddr(src);

      ref bufferIdx = bufferIdxs[loc];
      lSrcAddrs[loc][bufferIdx] = srcAddr;
      dstAddrs[loc][bufferIdx] = dstAddr;
      bufferIdx += 1;

      if bufferIdx == bufferSize {
        _flushBuffer(loc, bufferIdx, freeData=false);
        opsUntilYield = yieldFrequency;
      } else if opsUntilYield == 0 {
        currentTask.yieldExecution();
        opsUntilYield = yieldFrequency;
      } else {
        opsUntilYield -= 1;
      }
    }

```
- SrcAggregator per task simply copies the packet (in locale-wise buffer), and once #appends for any one locale = 1024 by a task, it calls flush operation.

`SrcAggregator.flush operation`

```
proc ref _flushBuffer(loc: int, ref bufferIdx, freeData) {
      const myBufferIdx = bufferIdx;
      if myBufferIdx == 0 then return;

      ref myLSrcVals = lSrcVals[loc];
      ref myRSrcAddrs = rSrcAddrs[loc];
      ref myRSrcVals = rSrcVals[loc];

      // Allocate remote buffers
      const rSrcAddrPtr = myRSrcAddrs.cachedAlloc();
      const rSrcValPtr = myRSrcVals.cachedAlloc();

      // Copy local addresses to remote buffer
      myRSrcAddrs.PUT(lSrcAddrs[loc], myBufferIdx);

      // Process remote buffer, copying the value of our addresses into a
      // remote buffer
      on Locales[loc] {
        for i in 0..<myBufferIdx {
          rSrcValPtr[i] = rSrcAddrPtr[i].deref();
        }
        if freeData {
          myRSrcAddrs.localFree(rSrcAddrPtr);
        }
      }
      if freeData {
        myRSrcAddrs.markFreed();
      }

      // Copy remote values into local buffer
      myRSrcVals.GET(myLSrcVals, myBufferIdx);

      // Assign the srcVal to the dstAddrs
      var dstAddrPtr = c_addrOf(dstAddrs[loc][0]);
      var srcValPtr = c_addrOf(myLSrcVals[0]);
      for i in 0..<myBufferIdx {
        dstAddrPtr[i].deref() = srcValPtr[i];
      }

      bufferIdx = 0;
    }
```

- On flush per locale, every task invokes `PUT` for desired addresses of indices and runs a blocking operation to copy the values to remote locale. After that, it runs GET operation to fetch the values. 

## Theoretical Understanding of SrcAggregator
- Runs per task, where every task knows address of A[] which is on shared memory (using shmem_malloc analogous). 
- Buffers are locale-wise and are flushed and executed in blocking way per task. If we view the same from process pov, i.e. per locale, certainly we do see overlap of comp and comm since per locale, otehr tasks can still perform their iteration. 
- Note, that conveyors overlaps comp and comm even for per task. Since, it allocates buffers per task, every task can perform comp for other PEs fetch (remote or local), whilst issuing communication call. Here backpressure kicks in, whereas in Chapel, blocking nature prevents this.  

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

## Results

- We observe `exstack` and `exstack2` go OUT-OF-MEMORY(OOM) at and beyond 1024 nodes.
- We observe `Conveyors` to be performant on scale.

## Running Chapel Program for 16M HugePageSize 
In addition to normal execution,
```
module load craype-hugepages16M
export CHPL_RT_USE_HUGEPAGES=yes
```

`conf_chapel_huge.sh`
This file checks whether the job is using `HugePageModules` correctly or not. This checks the env.

```
#!/bin/bash
#SBATCH -A csc607
#SBATCH -J chapel_ig
#SBATCH -t 0:40:00
#SBATCH -p batch
#SBATCH -S 0
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=64
#SBATCH --ntasks 1

export CHPL_LAUNCHER_ACCOUNT=csc607
export CHPL_LAUNCHER_WALLTIME=0:40:00
export CHPL_LAUNCHER_USE_SBATCH=1
export CHPL_LAUNCHER_QUEUE=batch
export CHPL_LAUNCHER_CPUS_PER_CU=64
export CHPL_RT_USE_HUGEPAGES=yes

export CHPL_LAUNCHER=slurm-srun
export CHPL_RT_MAX_HEAP_SIZE="50%"
export CHPL_LAUNCHER_MEM=unset
export CHPL_LAUNCHER_CORES_PER_LOCALE=64

export CHPL_LLVM=bundled
export CHPL_COMM=ofi
export CHPL_LOCALE_MODEL=flat
export CHPL_GPU=none

export CHPL_RT_USE_HUGEPAGES=yes
export CHPL_RT_PRINT_ENV=true

module load PrgEnv-gnu
module load cray-python
module load craype-hugepages16M

cd chapel/
source util/setchplenv.bash
cd test/studies/bale/aggregation/
srun -n 1 ./ig_real -nl 1 &
echo "Runtime env:"
env | grep HUGE
```
#### Output
```
Runtime env:
OLCF_FAMILY_CRAYPE_HUGEPAGES=craype-hugepages16M
PE_PRODUCT_LIST=CRAYPE:CRAY_PMI:CRAYPE_X86_TRENTO:PERFTOOLS:CRAYPAT:HUGETLB16M
HUGETLB_DEFAULT_PAGE_SIZE=16M
OLCF_FAMILY_CRAYPE_HUGEPAGES_VERSION=false
PE_PKGCONFIG_PRODUCTS=PE_HUGEPAGES:PE_LIBSCI:PE_MPICH:PE_DSMML:PE_PMI:PE_XPMEM
HUGETLB_MORECORE_HEAPBASE=10000000000
PE_HUGEPAGES_PKGCONFIG_VARIABLES=PE_HUGEPAGES_TEXT_SEGMENT:PE_HUGEPAGES_PAGE_SIZE
HUGETLB_MORECORE=yes
CHPL_RT_USE_HUGEPAGES=yes
LMOD_FAMILY_CRAYPE_HUGEPAGES_VERSION=false
LMOD_FAMILY_CRAYPE_HUGEPAGES=craype-hugepages16M
__LMOD_REF_COUNT_PE_PKGCONFIG_PRODUCTS=PE_HUGEPAGES:1;PE_LIBSCI:1;PE_MPICH:1;PE_DSMML:1;PE_PMI:1;PE_XPMEM:1
HUGETLB_FORCE_ELFMAP=yes+
HUGETLB_ELFMAP=W
__LMOD_REF_COUNT_PE_PRODUCT_LIST=CRAYPE:1;CRAY_PMI:1;CRAYPE_X86_TRENTO:1;PERFTOOLS:1;CRAYPAT:1;HUGETLB16M:1
```


## Contributors
Shubhendra Pal Singhal (ssinghal74@gatech.edu), Habanero Labs, USA
> Credits to Dr. Akihiro Hayashi (ahayashi@gatech.edu) for finding the performance reportings of Chapel.

> Credits to ORNL GRO internship with Dr. Oscar Hernandez (oscar@ornl.gov) and funding support for Frontier machine access.

> Credits to Dr. Wael Elwasif (elwasifwr@ornl.gov) for guiding us on Chapel installation on Frontier.

