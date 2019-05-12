// Approx. 0.15 microsecond (MacBook Air 2017)

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:ml_linalg/src/vector/float32/float32_vector.dart';

const amountOfElements = 10000;

class VectorUniqueBenchmark extends BenchmarkBase {
  VectorUniqueBenchmark()
      : super('Vector unnique elements obtaining, $amountOfElements elements');

  Float32Vector vector;

  static void main() {
    VectorUniqueBenchmark().report();
  }

  @override
  void run() {
    vector.unique();
  }

  @override
  void setup() {
    vector = Float32Vector.randomFilled(amountOfElements);
  }

  void tearDown() {
    vector = null;
  }
}

void main() {
  VectorUniqueBenchmark.main();
}
