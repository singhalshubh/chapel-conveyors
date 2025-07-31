PAPI_ROOT=/opt/cray/pe/papi/7.1.0.4
SRUN ?= oshrun

TARGETS= clean ig_block ig_cyclic

#export SCOREP_WRAPPER_INSTRUMENTER_FLAGS="--user"

all: $(TARGETS)

%: %.cpp
	cc -g -O3 -std=c++11 -DUSE_SHMEM=1 -ftrapv  -I$(BALE_INSTALL)/include -L$(BALE_INSTALL)/lib -o $@ $^ -I${PAPI_ROOT}/include -L${PAPI_ROOT}/lib -lpapi -lconvey -llibgetput -lspmat -lexstack -lm

clean:
	rm -f $(TARGETS)