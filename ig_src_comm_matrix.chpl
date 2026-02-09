use CyclicDist;
use BlockDist;
use Random;
use Time;
use CopyAggregation;
use CommDiagnostics;
use Atomics;  // for atomic int

// Locale-to-locale logical comm matrix
const LocMatDom = {0..#numLocales, 0..#numLocales};
var CommMat: [LocMatDom] atomic int;

const numTasksPerLocale = if dataParTasksPerLocale > 0 then dataParTasksPerLocale
                                                       else here.maxTaskPar;
const numTasks = numLocales * numTasksPerLocale;
config const N = 1000000; // number of updates per task
config const M = 10000;   // number of entries in the table per task

const numUpdates = N * numTasks;
const tableSize = M * numTasks;

// Block array access is faster than Cyclic currently. We hadn't
// optimized these before because the comm overhead dominated, but
// that's no longer true with aggregation. `-suseBlockArr` (the
// default) and/or `-sdefaultDisableLazyRADOpt` will help indexing
// speed until we optimize them.
config param useBlockArr = true;

var t: stopwatch;
proc startTimer() {
  t.start();
}
proc stopTimer(name) {
    t.stop(); var src = t.elapsed(); t.clear();
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

  startTimer();
  startCommDiagnostics();
  forall (t, r) in zip(tmp, Rindex) with (var agg = new SrcAggregator(int)) {
    // ---- locale-to-locale comm matrix instrumentation ----
    const src = here.id;
    const dst = D.distribution.idxToLocale(r).id;
    CommMat[src, dst].add(1);
    agg.copy(t, A[r]);
  }
  stopCommDiagnostics();
  writeln(getCommDiagnosticsHere());
  printCommDiagnosticsTable();
  stopTimer("AGG");

  // --------- print the locale-to-locale matrix ----------
  writeln("\nLocale-to-Locale Communication Matrix (logical accesses to A[r]):");

  writef("%7s", "");
  for d in 0..#numLocales do
    writef(" %12s", "dst " + d:string);
  writeln();

  for s in 0..#numLocales {
    writef("src %2i:", s);
    for d in 0..#numLocales {
      writef(" %12i", CommMat[s, d].read());
    }
    writeln();
  }
  // -------------------------------------------------------
}
