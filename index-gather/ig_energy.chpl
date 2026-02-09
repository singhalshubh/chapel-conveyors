use CyclicDist;
use BlockDist;
use Random;
use Time;
use CopyAggregation;

extern {
  #include <papi.h>

  int papi_ok = 1, eventset = PAPI_NULL;
  long long val[1] = {0};

  void   papi_start(void);
  double papi_stop(void);

  void papi_start(void) {
    if (PAPI_library_init(PAPI_VER_CURRENT) != PAPI_VER_CURRENT) papi_ok = 0;
    if (papi_ok && PAPI_create_eventset(&eventset) != PAPI_OK) papi_ok = 0;
    if (papi_ok && PAPI_add_named_event(eventset, "cray_pm:::PM_ENERGY:NODE") != PAPI_OK) papi_ok = 0;
    if (papi_ok && PAPI_start(eventset) != PAPI_OK) papi_ok = 0;
  }

  double papi_stop(void) {
    if (papi_ok && PAPI_stop(eventset, val) == PAPI_OK)
        return (double) val[0];
    return 0.0;
  }
}

extern proc papi_start(): void;
extern proc papi_stop(): c_double;

const numTasksPerLocale = if dataParTasksPerLocale > 0 then dataParTasksPerLocale
                                                       else here.maxTaskPar;
const numTasks = numLocales * numTasksPerLocale;

config const N = 1000000;
config const M = 10000;

const numUpdates = N * numTasks;
const tableSize = M * numTasks;

config param useBlockArr = true;

var t: stopwatch;
proc startTimer() { t.start(); }
proc stopTimer(name) {
  t.stop();
  var src = t.elapsed();
  t.clear();
  const bytesPerTask = 2 * N * numBytes(int);
  const gbPerNode = bytesPerTask:real / (10**9):real * numTasksPerLocale;
  writef("%10s:\t%.3dr seconds\t%.3dr GB/s/node\n", name, src, gbPerNode/src);
}

proc main() {
  const D = if useBlockArr then blockDist.createDomain(0..#tableSize)
                           else cyclicDist.createDomain(0..#tableSize);
  var A: [D] int = D;

  const UpdatesDom = blockDist.createDomain(0..#numUpdates);
  var Rindex: [UpdatesDom] int;

  fillRandom(Rindex, 208);
  Rindex = mod(Rindex, tableSize);
  var tmp: [UpdatesDom] int = -1;

  var perLocaleEnergy: [Locales.domain] real;

  coforall loc in Locales do on loc {
    papi_start();
  }

  startTimer();
  forall (tLocal, r) in zip(tmp, Rindex) with (var agg = new SrcAggregator(int)) {
    agg.copy(tLocal, A[r]);
  }

  coforall loc in Locales do on loc {
    const e = papi_stop();
    perLocaleEnergy[here.id] = e;
  }

  const total_energy = + reduce perLocaleEnergy;
  stopTimer("AGG");

  writef("TOTAL MEMORY ENERGY (PM_ENERGY:MEMORY) = %.3dr J across %i locales\n",
          total_energy, numLocales);
}
