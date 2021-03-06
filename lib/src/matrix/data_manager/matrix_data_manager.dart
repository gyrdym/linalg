import 'package:ml_linalg/dtype.dart';
import 'package:ml_linalg/vector.dart';

abstract class MatrixDataManager {
  DType get dtype;
  int get rowsNum;
  int get columnsNum;
  Iterator<Iterable<double>> get iterator;
  Iterable<int> get rowIndices;
  Iterable<int> get columnIndices;
  bool get hasData;
  Vector getColumn(int index);
  Vector getRow(int index);
  bool get areAllRowsCached;
  bool get areAllColumnsCached;
}
