## Radix Sort
This profiling is inspired from https://dl.acm.org/doi/10.1145/3731599.3767500, which acheives performance as Conveyors. (git clone https://github.com/hpc-ai-adv-dev/distributed-lsb/). The credit belongs to authors of the paper (https://dl.acm.org/doi/10.1145/3731599.3767500) who implemented the benchmark. We only claim the profiling additions and results as our contribution. 

## Installation and Running on Frontier
In this, we showcase example of running $2^30$ elements per node, for radix sort benchmark. Run the benchmark for performance. Run the codes available here only to collect energy metrics!

### Chapel

#### Installation
chpl arkouda-radix-sort-strided-counts.chpl --fast

#### SLURM script
```
#!/bin/bash
#SBATCH -A <>
#SBATCH -J chapel_radix
#SBATCH -t 0:40:00
#SBATCH -p batch
#SBATCH -S 0
#SBATCH --exclusive
#SBATCH -N 256

NODES=256

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
cd ../distributed-lsb/chpl/
## data scales are overall problem size. Its total

SIZE=$((1073741824*NODES))
srun -N ${NODES} -n $((4*NODES)) -c 16 --cpu-bind=none --exclusive ./arkouda-radix-sort-strided-counts_real -nl ${NODES}x4numa --n=${SIZE}
```

### OpenSHMEM
This contains installation and running of Conveyors and AGP (native OpenSHMEM) benchmark
#### Installation
```
PAPI_ROOT=/opt/cray/pe/papi/7.1.0.4
[Conveyors] CC -g -O3 -std=c++17 -DUSE_SHMEM=1 -ftrapv -DNDEBUG shmem_lsbsort_convey.cpp -I${BALE_INSTALL}/include -o shmem_lsbsort_convey -I pcg-cpp/include/ -I${PAPI_ROOT}/include -L${PAPI_ROOT}/lib -L${BALE_INSTALL}/lib -lconvey -llibgetput -lspmat -lexstack -lpapi -lm

[AGP] CC -g -O3 -std=c++17 -DUSE_SHMEM=1 -ftrapv -DNDEBUG shmem_lsbsort.cpp -I${BALE_INSTALL}/include -o shmem_lsbsort -I pcg-cpp/include/ -I${PAPI_ROOT}/include -L${PAPI_ROOT}/lib -L${BALE_INSTALL}/lib -lconvey -llibgetput -lspmat -lexstack -lpapi -lm
```

> If you want to use PAPI profiling, please refer to the codes in this directory. The changes are prevelant to addition of PAPI APIs and including header files
extern "C" {
#include <convey.h>
#include <spmat.h>
}

#### SLURM script
```
#!/bin/bash
#SBATCH -A <>
#SBATCH -J bale_rd
#SBATCH -t 00:20:00
#SBATCH -p batch
#SBATCH --ntasks-per-node=64
#SBATCH -S 0
#SBATCH --exclusive
#SBATCH -N 256

NODES=256

cd $SLURM_SUBMIT_DIR
source oshmem-slurm.sh (This is the script which has installation of bale and setting library paths)
cd distributed-lsb/shmem
module load papi

SIZE=$((1073741824*NODES))

srun -N $NODES -n $((NODES*64)) ./shmem_lsbsort  --n $SIZE
srun -N $NODES -n $((NODES*64)) ./shmem_lsbsort_convey --n $SIZE

## PAPI_ROOT=/opt/cray/pe/papi/7.1.0.4

## [Conveyors] 
CC -g -O3 -std=c++17 -DUSE_SHMEM=1 -ftrapv -DNDEBUG shmem_lsbsort_convey.cpp -I${BALE_INSTALL}/include -o shmem_lsbsort_convey -I pcg-cpp/include/ -I${PAPI_ROOT}/include -L${PAPI_ROOT}/lib -L${BALE_INSTALL}/lib -lconvey -llibgetput -lspmat -lexstack -lpapi -lm

## [AGP] 
CC -g -O3 -std=c++17 -DUSE_SHMEM=1 -ftrapv -DNDEBUG shmem_lsbsort.cpp -I${BALE_INSTALL}/include -o shmem_lsbsort -I pcg-cpp/include/ -I${PAPI_ROOT}/include -L${PAPI_ROOT}/lib -L${BALE_INSTALL}/lib -lconvey -llibgetput -lspmat -lexstack -lpapi -lm
```


