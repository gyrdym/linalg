import 'package:ml_linalg/dtype.dart';
import 'package:ml_linalg/linalg.dart';
import 'package:ml_linalg/src/common/exception/matrix_division_by_vector_exception.dart';
import 'package:ml_linalg/src/common/exception/square_matrix_division_by_vector_exception.dart';
import 'package:test/test.dart';

import '../../../../dtype_to_title.dart';

void matrixDivisionOperatorTestGroupFactory(DType dtype) =>
    group(dtypeToMatrixTestTitle[dtype], () {
      group('/ operator', () {
        test('should perform row-wise division by a vector', () {
          final matrix = Matrix.fromList([
            [4.0, 6.0, 20.0, 125.0],
            [10.0, 18.0, 28.0, 40.0],
            [18.0, .0, -12.0, -35.0],
          ], dtype: dtype);

          final vector = Vector.fromList([2.0, 3.0, 4.0, 5.0], dtype: dtype);
          final actual = matrix / vector;

          final expected = [
            [2.0, 2.0, 5.0, 25.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, .0, -3.0, -7.0],
          ];

          expect(actual, equals(expected));
          expect(actual.rowsNum, 3);
          expect(actual.columnsNum, 4);
          expect(actual.dtype, dtype);
        });

        test('should perform column-wise division by a vector', () {
          final matrix = Matrix.fromList([
            [4.0, 6.0, 20.0, 120.0],
            [9.0, 18.0, 27.0, 45.0],
            [14.0, .0, -21.0, -35.0],
          ], dtype: dtype);

          final vector = Vector.fromList([2.0, 3.0, 7.0], dtype: dtype);
          final actual = matrix / vector;

          final expected = [
            [2.0, 3.0, 10.0, 60.0],
            [3.0, 6.0, 9.0, 15.0],
            [2.0, .0, -3.0, -5.0],
          ];

          expect(actual, equals(expected));
          expect(actual.rowsNum, 3);
          expect(actual.columnsNum, 4);
          expect(actual.dtype, dtype);
        });

        test('should throw an error if one tries to divide a matrix by a '
            'vector of unproper length', () {
          final matrix = Matrix.fromList([
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, .0, -2.0, -3.0],
          ], dtype: dtype);

          final vector = Vector.fromList([2.0, 3.0, 4.0, 5.0, 7.0],
              dtype: dtype);

          expect(() => matrix / vector,
              throwsA(isA<MatrixDivisionByVectorException>()));
        });

        test('should throw an error if one tries to divide a square matrix '
            'by a vector', () {
          final matrix = Matrix.fromList([
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, .0, -2.0, -3.0],
            [9.0, .0, -2.0, -3.0],
          ], dtype: dtype);

          final vector = Vector.fromList([2.0, 3.0, 4.0, 5.0],
              dtype: dtype);

          expect(() => matrix / vector,
              throwsA(isA<SquareMatrixDivisionByVectorException>()));
        });

        test('should perform division of a matrix by another matrix', () {
          final matrix1 = Matrix.fromList([
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, .0, -2.0, -3.0],
          ], dtype: dtype);

          final matrix2 = Matrix.fromList([
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, 1.0, -2.0, -3.0],
          ], dtype: dtype);

          final actual = matrix1 / matrix2;

          final expected = [
            [1.0, 1.0, 1.0, 1.0],
            [1.0, 1.0, 1.0, 1.0],
            [1.0, .0, 1.0, 1.0],
          ];

          expect(actual, equals(expected));
          expect(actual.rowsNum, 3);
          expect(actual.columnsNum, 4);
          expect(actual.dtype, dtype);
        });

        test('should throw an error if one tries to divide a matrix by another '
            'matrix of unproper shape', () {
          final matrix1 = Matrix.fromList([
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, .0, -2.0, -3.0],
          ], dtype: dtype);

          final matrix2 = Matrix.fromList([
            [1.0, 2.0],
            [5.0, 6.0],
            [9.0, .0],
          ], dtype: dtype);

          expect(() => matrix1 / matrix2, throwsException);
        });

        test('should perform division of a matrix by a scalar', () {
          final matrix1 = Matrix.fromList([
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, .0, -2.0, -3.0],
          ], dtype: dtype);

          final scalar = 2.0;
          final actual = matrix1 / scalar;
          final expected = [
            [.5, 1.0, 1.5, 2.0],
            [2.5, 3.0, 3.5, 4.0],
            [4.5, .0, -1.0, -1.5],
          ];

          expect(actual, equals(expected));
          expect(actual.rowsNum, 3);
          expect(actual.columnsNum, 4);
          expect(actual.dtype, dtype);
        });
      });
    });
