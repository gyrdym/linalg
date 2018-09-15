import 'dart:math' as math;
import 'dart:typed_data';

import 'norm.dart';
import 'vector.dart';

part 'float32x4_vector.dart';
part 'float64x2_vector.dart';

/// Vector with SIMD (single instruction, multiple data) architecture support
///
/// An entity, that extends this class, may have potentially infinite length (in terms of vector algebra - number of
/// dimensions). Vector components are contained in a special typed data structure, that allow to perform vector operations
/// extremely fast due to hardware assisted computations.
///
/// Let's assume some considerations:
/// - High performance of vector operations is provided by SIMD types of Dart language
/// - Each SIMD-typed value is a "cell", that contains several floating point values (2 or 4).
/// - Sequence of SIMD-values forms a "computation lane", where computations are performed with each floating point element
/// simultaneously (in parallel)
abstract class _SIMDVector<SIMDListType extends List, TypedListType extends List, SIMDValueType>
    implements Vector {

  /// An efficient SIMD list
  SIMDListType _innerList;

  /// If a [_SIMDVector] is created from a list whose length % [_bucketSize] != 0, residual stores here
  SIMDValueType _residualBucket;

  /// A number of vector elements
  int _length;

  /// Computation lane width (lane supports 2 or 4 elements to be processed simultaneously, this characteristic
  /// restricted by computing platform architecture)
  int get _bucketSize;

  int get _bucketsNumber => _innerList.length + (_residualBucket != null ? 1 : 0);

  /// Creates a vector with both empty simd and typed inner lists
  _SIMDVector(int length) {
    _length = length;
    _innerList = _createSIMDList(length);
  }

  /// Creates a vector from collection
  _SIMDVector.from(Iterable<double> source) {
    final _source = source is List ? source : source.toList(growable: false);
    _length = _source.length;
    _innerList = _convertCollectionToSIMDList(_source);
    _residualBucket = _cutResidualBucket(_source);
  }

  /// Creates a vector from SIMD-typed (Float32x4, Float64x2) list
  _SIMDVector.fromSIMDList(SIMDListType source, [int origLength]) {
    _length = origLength ?? source.length * _bucketSize;
    _residualBucket = _cutResidualBucket(source);
    _innerList = _residualBucket == null ? source : source.sublist(0, source.length - 1);
  }

  /// Creates a SIMD-vector with length equals [length] and fills all elements of created vector with a [value]
  _SIMDVector.filled(int length, double value) {
    final source = new List<double>.filled(length, value);
    _length = length;
    _innerList = _convertCollectionToSIMDList(source);
    _residualBucket = _cutResidualBucket(source);
  }

  /// Creates a SIMD-vector with length equals [length] and fills all elements of created vector with a zero
  _SIMDVector.zero(int length) {
    final source = new List<double>.filled(length, 0.0);
    _length = length;
    _innerList = _convertCollectionToSIMDList(source);
    _residualBucket = _cutResidualBucket(source);
  }

  /// Creates a SIMD-vector with length equals [length] and fills all elements of created vector with a random value
  _SIMDVector.randomFilled(int length, {int seed}) {
    final random = new math.Random(seed);
    final source = new List<double>.generate(length, (_) => random.nextDouble());
    _length = length;
    _innerList = _convertCollectionToSIMDList(source);
    _residualBucket = _cutResidualBucket(source);
  }

  /// A number of vector elements
  @override
  int get length => _length;

  @override
  _SIMDVector operator +(_SIMDVector vector) => _elementWiseVectorOperation(vector, (a, b) => a + b);

  @override
  _SIMDVector operator -(_SIMDVector vector) => _elementWiseVectorOperation(vector, (a, b) => a - b);

  @override
  _SIMDVector operator *(_SIMDVector vector) => _elementWiseVectorOperation(vector, (a, b) => a * b);

  @override
  _SIMDVector operator /(_SIMDVector vector) => _elementWiseVectorOperation(vector, (a, b) => a / b);

  @override
  _SIMDVector toIntegerPower(int power) => _elementWisePow(power);

  @override
  _SIMDVector scalarMul(double value) => _elementWiseScalarOperation(value, (a, b) => a * b);

  @override
  _SIMDVector scalarDiv(double value) => _elementWiseScalarOperation(value, (a, b) => a / b);

  @override
  _SIMDVector scalarAdd(double value) => _elementWiseScalarOperation(value, (a, b) => a + b);

  @override
  _SIMDVector scalarSub(double value) => _elementWiseScalarOperation(value, (a, b) => a - b);

  /// Returns a vector filled with absolute values of an each component of [this] vector
  @override
  _SIMDVector abs() => _elementWiseSelfOperation((SIMDValueType value) => _SIMDAbs(value));

  @override
  _SIMDVector copy() => _elementWiseSelfOperation((SIMDValueType value) => value);

  @override
  double dot(_SIMDVector vector) => (this * vector).sum();

  /// Returns sum of all vector components
  @override
  double sum() {
    final sum = _residualBucket == null
      ? _innerList.reduce((SIMDValueType sum, SIMDValueType item) => _SIMDSum(item, sum))
      : _innerList.fold(_residualBucket, (SIMDValueType sum, SIMDValueType item) => _SIMDSum(item, sum));
    return _singleSIMDSum(sum);
  }

  @override
  double distanceTo(_SIMDVector vector, [Norm norm = Norm.EUCLIDEAN]) => (this - vector).norm(norm);

  @override
  double mean() => sum() / length;

  @override
  double norm([Norm norm = Norm.EUCLIDEAN]) {
    final power = _getPowerByNormType(norm);
    if (power == 1) {
      return this.abs().sum();
    }
    return math.pow(toIntegerPower(power).sum(), 1 / power);
  }

  @override
  double max() {
    final max = _getMaxLane(_innerList.reduce(_selectMax));
    if (_residualBucket != null) {
      return _SIMDToList(_residualBucket)
          .take(_length % _bucketSize)
          .fold(max, (double max, double val) => math.max(max, val));
    } else {
      return max;
    }
  }

  @override
  double min() {
    final min = _getMinLane(_innerList.reduce(_selectMin));
    if (_residualBucket != null) {
      return _SIMDToList(_residualBucket)
          .take(_length % _bucketSize)
          .fold(min, (double min, double val) => math.min(min, val));
    } else {
      return min;
    }
  }

  /// Returns exponent depending on vector norm type (for Euclidean norm - 2, Manhattan - 1)
  int _getPowerByNormType(Norm norm) {
    switch(norm) {
      case Norm.EUCLIDEAN:
        return 2;
      case Norm.MANHATTAN:
        return 1;
      default:
        throw new UnsupportedError('Unsupported norm type!');
    }
  }

  /// Returns a SIMD value raised to the integer power
  SIMDValueType _simdToIntPow(SIMDValueType lane, int power) {
    if (power == 0) {
      return _createSIMDFilled(1.0);
    }

    final x = _simdToIntPow(lane, power ~/ 2);
    final sqrX = _SIMDProduct(x, x);

    if (power % 2 == 0) {
      return sqrX;
    }

    return _SIMDProduct(lane, sqrX);
  }

  /// Returns SIMD list (e.g. Float32x4List) as a result of converting iterable source
  ///
  /// All sequence of [collection] elements splits into groups with [_bucketSize] length
  SIMDListType _convertCollectionToSIMDList(Iterable<double> collection) {
    final numOfBuckets = collection.length ~/ _bucketSize;
    final source = collection is TypedListType ? collection : _createTypedListFromList(collection);
    final target = _createSIMDList(numOfBuckets);

    for (int i = 0; i < numOfBuckets; i++) {
      final start = i * _bucketSize;
      final end = start + _bucketSize;
      final bucketAsList = source.sublist(start, end);
      target[i] = _createSIMDFromSimpleList(bucketAsList);
    }

    return target;
  }

  SIMDValueType _cutResidualBucket(List collection) {
    if (collection is SIMDListType) {
      if (collection.length % _bucketSize > 0) {
        return collection.last;
      } else {
        return null;
      }
    }

    final length = collection.length;
    final numOfBuckets = length ~/ _bucketSize;
    final exceeded = length % _bucketSize;
    final residue = new List<double>.generate(exceeded, (int idx) => collection[numOfBuckets * _bucketSize + idx]);
    return _createSIMDFromSimpleList(residue);
  }

  /// Returns a vector as a result of applying to [this] any element-wise operation with a scalar (e.g. vector addition)
  _SIMDVector _elementWiseScalarOperation(double value, SIMDValueType operation(SIMDValueType a, SIMDValueType b)) {
    final scalar = _createSIMDFilled(value);
    final list = _createSIMDList(_bucketsNumber);
    for (int i = 0; i < _innerList.length; i++) {
      list[i] = operation(_innerList[i], scalar);
    }
    if (this._residualBucket != null) {
      list[list.length - 1] = operation(_residualBucket, scalar);
    }
    return _createVectorFromSIMDList(list, _length);
  }

  /// Returns a vector as a result of applying to [this] any element-wise operation with a vector (e.g. vector addition)
  _SIMDVector _elementWiseVectorOperation(_SIMDVector vector, SIMDValueType operation(SIMDValueType a, SIMDValueType b)) {
    if (vector.length != length) throw _mismatchLengthError();
    final list = _createSIMDList(_bucketsNumber);
    for (int i = 0; i < _innerList.length; i++) {
      list[i] = operation(_innerList[i], vector._innerList[i]);
    }
    if (_residualBucket != null) {
      list[list.length - 1] = operation(_residualBucket, vector._residualBucket);
    }
    return _createVectorFromSIMDList(list, _length);
  }

  _SIMDVector _elementWiseSelfOperation(SIMDValueType operation(SIMDValueType a)) {
    final list = _createSIMDList(_bucketsNumber);
    for (int i = 0; i < _innerList.length; i++) {
      list[i] = operation(_innerList[i]);
    }
    if (_residualBucket != null) {
      list[list.length - 1] = operation(_residualBucket);
    }
    return _createVectorFromSIMDList(list, _length);
  }

  /// Returns a vector as a result of applying to [this] element-wise raising to the integer power
  _SIMDVector _elementWisePow(int exp) {
    final list = _createSIMDList(_bucketsNumber);
    for (int i = 0; i < _innerList.length; i++) {
      list[i] = _simdToIntPow(_innerList[i], exp);
    }
    if (_residualBucket != null) {
      list[list.length - 1] = _simdToIntPow(_residualBucket, exp);
    }
    return _createVectorFromSIMDList(list, _length);
  }

  _SIMDVector query(Iterable<int> indexes) {
    final list = _createTypedList(indexes.length);
    int i = 0;
    for (final idx in indexes) {
      list[i++] = this[idx];
    }
    return _createVectorFromList(list);
  }

  _SIMDVector unique() {
    final unique = <double>[];
    for (int i = 0; i < _length; i++) {
      final el = this[i];
      if (!unique.contains(el)) {
        unique.add(el);
      }
    }
    return _createVectorFromList(unique);
  }

  double operator [](int index) {
    if (index >= _length) throw new RangeError.index(index, this);
    final base = (index / _bucketSize).floor();
    final offset = index - base * _bucketSize;
    if (index >= _innerList.length * _bucketSize) return _getScalarByOffsetIndex(_residualBucket, offset);
    return _getScalarByOffsetIndex(_innerList[base], offset);
  }

  void operator []=(int index, double element) {
    throw new UnsupportedError('`[]=` operator is unsupported');
  }

  @override
  List<double> toList() => new List<double>.generate(_length, (int idx) => this[idx]);

  // Factory methods are below
  SIMDValueType _createSIMDFilled(double value);
  SIMDValueType _createSIMDFromSimpleList(List<double> list);
  SIMDValueType _SIMDProduct(SIMDValueType a, SIMDValueType b);
  SIMDValueType _SIMDSum(SIMDValueType a, SIMDValueType b);
  SIMDValueType _SIMDAbs(SIMDValueType a);
  double _singleSIMDSum(SIMDValueType a);
  SIMDListType _createSIMDList(int length);
  TypedListType _createTypedList(int length);
  TypedListType _createTypedListFromList(List<double> list);
  _SIMDVector _createVectorFromSIMDList(SIMDListType list, int length);
  _SIMDVector _createVectorFromList(List<double> list);
  double _getScalarByOffsetIndex(SIMDValueType value, int offset);
  SIMDValueType _selectMax(SIMDValueType a, SIMDValueType b);
  double _getMaxLane(SIMDValueType a);
  SIMDValueType _selectMin(SIMDValueType a, SIMDValueType b);
  double _getMinLane(SIMDValueType a);
  List<double> _SIMDToList(SIMDValueType a);

  RangeError _mismatchLengthError() => new RangeError('Vectors length must be equal');
}