/*
* This file is part of OpenModelica.
*
* Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the Open Source Modelica
* Consortium (OSMC) Public License (OSMC-PL) are obtained
* from OSMC, either from the above address,
* from the URLs: http:www.ida.liu.se/projects/OpenModelica or
* http:www.openmodelica.org, and in the OpenModelica distribution.
* GNU version 3 is obtained from: http:www.gnu.org/copyleft/gpl.html.
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of  MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*/

/*
  Minimal test case for record-as-function-argument pattern.
  This mimics the MSL PendulumTest pattern where:
  1. A record type has array fields
  2. A function takes the record as input
  3. The function result is used in start values
*/

package RecordFunctionTest

  // Simple record mimicking MSL's Orientation
  record Transform
    Real[3, 3] T;  // Transformation matrix
    Real[3] w;     // Angular velocity
  end Transform;

  // Function that takes a record and returns an array (like resolve2)
  function transformVector
    input Transform R;
    input Real[3] v;
    output Real[3] result;
  algorithm
    result := R.T * v;
  end transformVector;

  // Simple model using the pattern
  model SimpleTransform
    parameter Transform R_start = Transform(
      T = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}},
      w = {0, 0, 0}
    );
    parameter Real[3] v_start = {1, 2, 3};
    parameter Real[3] v_init = transformVector(R_start, v_start);

    Real[3] v_transformed(start = v_init);
    Real x(start = v_init[1]);

  equation
    der(v_transformed) = {0, 0, 0};
    der(x) = 0;
  end SimpleTransform;

  // Even simpler: just record field access
  model RecordFieldAccess
    parameter Transform R = Transform(
      T = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}},
      w = {1, 2, 3}
    );

    // Direct field access
    Real[3] w_copy(start = R.w);
    Real w1(start = R.w[1]);

  equation
    der(w_copy) = {0, 0, 0};
    der(w1) = 0;
  end RecordFieldAccess;

  // Test 2D array subscript access from record parameters
  model RecordFieldAccess2D
    parameter Transform R = Transform(
      T = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}},
      w = {0, 0, 0}
    );

    // 2D subscript access: R.T[row, col]
    Real t11(start = R.T[1,1]);  // Expected: 1.0
    Real t12(start = R.T[1,2]);  // Expected: 2.0
    Real t23(start = R.T[2,3]);  // Expected: 6.0
    Real t32(start = R.T[3,2]);  // Expected: 8.0

  equation
    der(t11) = 0;
    der(t12) = 0;
    der(t23) = 0;
    der(t32) = 0;
  end RecordFieldAccess2D;

  // Test subscripted access in equations
  model RecordFieldAccessEquation
    parameter Transform R = Transform(
      T = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}},
      w = {1, 2, 3}
    );

    Real x(start = 0);

  equation
    der(x) = R.w[2];
  end RecordFieldAccessEquation;

  // Test 2D subscripted access in equations
  model RecordFieldAccessEquation2D
    parameter Transform R = Transform(
      T = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}},
      w = {0, 0, 0}
    );

    Real x(start = 0);

  equation
    der(x) = R.T[2,3];
  end RecordFieldAccessEquation2D;

  // Test subscripted access to array state variables in equations
  model ArrayStateSubscript
    Real[3] x(start = {1, 2, 3});
    Real[3] y(start = {0, 0, 0});

  equation
    der(x[1]) = 0;
    der(x[2]) = 0;
    der(x[3]) = 0;
    y[1] = x[1];
    y[2] = x[2];
    y[3] = x[3];
  end ArrayStateSubscript;

  // Test array equality between record fields (like Pendulum: frame_b.R.w = frame_a.R.w)
  model RecordArrayEquality
    parameter Transform R1 = Transform(
      T = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}},
      w = {1, 2, 3}
    );
    Real[3] w_copy(start = {0, 0, 0});
    Real x(start = 0);

  equation
    w_copy = R1.w;
    der(x) = w_copy[2];
  end RecordArrayEquality;

  // Test array field copy between two record instances
  model RecordFieldCopy
    parameter Transform R1 = Transform(
      T = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}},
      w = {1, 2, 3}
    );
    parameter Transform R2 = Transform(
      T = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}},
      w = R1.w
    );
    Real x(start = 0);

  equation
    der(x) = R2.w[2];
  end RecordFieldCopy;

  // Test nested component with record parameter (mimics pendulum.body.R_start pattern)
  model Body
    parameter Transform R_start = Transform(
      T = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}},
      w = {1, 2, 3}
    );
    Real x(start = 0);
  equation
    der(x) = R_start.w[1];
  end Body;

  model NestedRecordAccess
    Body body;
    Real y(start = 0);
  equation
    der(y) = body.R_start.w[2];
  end NestedRecordAccess;

  // Test nested component with function call on record (mimics resolve2(pendulum.body.R_start, ...)[1])
  model NestedRecordFunction
    Body body;
    parameter Real[3] v = {1, 0, 0};
    Real[3] result;
    Real y(start = 0);
  equation
    result = transformVector(body.R_start, v);
    der(y) = result[1];
  end NestedRecordFunction;

  // Test 2D matrix array equation expansion (nested DAE.ARRAY flattening)
  model MatrixArrayEquation
    parameter Real[3,3] T_param = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
    Real[3,3] T;
    Real x(start = 0);
  equation
    T = T_param;
    der(x) = T[2,2];  // Should be 1.0
  end MatrixArrayEquation;

  // Function that accesses individual elements of record array fields
  // This triggers the double-subscript bug: R.T[1,1] becomes R_T[1,1][1,1]
  // after record flattening, because string(componentRef) includes subscripts
  // in the name AND they are preserved separately as CREF subscripts.
  function getFirstDiag
    input Transform R;
    output Real result;
  algorithm
    result := R.T[1,1] + R.w[1];
  end getFirstDiag;

  model RecordFieldSubscriptInFunction
    parameter Transform R = Transform(
      T = {{2, 0, 0}, {0, 3, 0}, {0, 0, 4}},
      w = {10, 20, 30}
    );
    Real x(start = 0);
  equation
    // getFirstDiag(R) = R.T[1,1] + R.w[1] = 2 + 10 = 12
    der(x) = getFirstDiag(R);
  end RecordFieldSubscriptInFunction;

  // ========================================================================
  // Tests for array-returning functions called with symbolic (state var) args.
  // These reproduce the Pendulum BoundsError pattern where the function
  // wrapper returns scalar Symbolics.Num instead of an array.
  // ========================================================================

  // Simple array-returning function (no control flow, no records)
  function doubleVec
    input Real[3] v;
    output Real[3] result;
  algorithm
    result := {v[1] * 2, v[2] * 2, v[3] * 2};
  end doubleVec;

  // Test A: array-returning func, state var args, result assigned to array var.
  // The backend scalarizes w = doubleVec(v) into:
  //   0 = doubleVec(v)[1] - w[1]
  //   0 = doubleVec(v)[2] - w[2]
  //   0 = doubleVec(v)[3] - w[3]
  // The wrapper detects symbolic v and returns scalar Num.
  // Indexing [2] on scalar Num gives BoundsError.
  model ArrayFuncResultIndexed
    Real[3] v(start = {1, 2, 3});
    Real[3] w;
    Real x(start = 0);
  equation
    der(v) = {0, 0, 0};
    w = doubleVec(v);
    // w[2] = doubleVec({1,2,3})[2] = 4, so der(x) = 4, x(1) = 4.0
    der(x) = w[2];
  end ArrayFuncResultIndexed;

  // Test B: record func, state var args, result assigned to array var.
  // Adds the record flattening dimension to the pattern.
  model RecordFuncResultIndexed
    parameter Transform R = Transform(
      T = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}},
      w = {0, 0, 0}
    );
    Real[3] v(start = {1, 2, 3});
    Real[3] result;
    Real x(start = 0);
  equation
    der(v) = {0, 0, 0};
    result = transformVector(R, v);
    // result[1] = transformVector(I, {1,2,3})[1] = 1, so der(x) = 1, x(1) = 1.0
    der(x) = result[1];
  end RecordFuncResultIndexed;

  // Function with control flow (if-else), returns scalar
  function absFirstElement
    input Real[3] v;
    output Real result;
  algorithm
    if v[1] > 0 then
      result := v[1];
    else
      result := -v[1];
    end if;
  end absFirstElement;

  // Test C: function with if-else, state var args
  // The wrapper calls implementation with symbolic args.
  // The if-condition produces symbolic Num, not Bool: TypeError.
  model ControlFlowFuncSymbolicArgs
    Real[3] v(start = {1, 2, 3});
    Real x(start = 0);
  equation
    der(v) = {0, 0, 0};
    // absFirstElement({1,2,3}) = 1, so der(x) = 1, x(1) = 1.0
    der(x) = absFirstElement(v);
  end ControlFlowFuncSymbolicArgs;

  // ========================================================================
  // Tests for record-to-record pass-through equations inside components.
  // This pattern appears in MSL FixedTranslation: frame_b.R = frame_a.R
  // where R is a record with array fields (T[3,3], w[3]).
  // The backend must scalarize these into individual equations referencing
  // scalarized variable names like var"comp_R_out_T[1][1]" instead of
  // bare symbol indexing like comp_R_out_T[1, 1].
  // ========================================================================

  // Component that passes a record through: R_out = R_in
  // Mimics MSL FixedTranslation's frame_b.R = frame_a.R
  model Passthrough
    Transform R_in;
    Transform R_out;
  equation
    R_out = R_in;
  end Passthrough;

  // Simplest test: 1D array field pass-through in a component equation
  // R_in.w = {1,2,3}, R_out.w = R_in.w via the Passthrough component.
  // der(x) = pt.R_out.w[2] = 2.0, so x(1) = 2.0.
  model RecordPassthrough1D
    Passthrough pt;
    Real x(start = 0);
  equation
    pt.R_in.T = {{1,0,0},{0,1,0},{0,0,1}};
    pt.R_in.w = {1, 2, 3};
    der(x) = pt.R_out.w[2];
  end RecordPassthrough1D;

  // Full test: 2D matrix field pass-through in a component equation
  // R_in.T = {{1,2,3},{4,5,6},{7,8,9}}, R_out.T = R_in.T via Passthrough.
  // der(x) = pt.R_out.T[2,3] = 6.0, so x(1) = 6.0.
  // This is the exact pattern that fails in the DoublePendulum (BoundsError
  // on R_T[1,1] because it generates bare symbol indexing instead of
  // scalarized variable names).
  model RecordPassthroughMatrix
    Passthrough pt;
    Real x(start = 0);
  equation
    pt.R_in.T = {{1,2,3},{4,5,6},{7,8,9}};
    pt.R_in.w = {0, 0, 0};
    der(x) = pt.R_out.T[2,3];
  end RecordPassthroughMatrix;

  // ---- Even simpler: record with only a 1D vector field ----
  record Vec3Record
    Real[3] w;
  end Vec3Record;

  model Vec3Passthrough
    Vec3Record R_in;
    Vec3Record R_out;
  equation
    R_out = R_in;
  end Vec3Passthrough;

  // Minimal test: 1D-only record pass-through in a component equation.
  // R_in.w = {1,2,3}, R_out = R_in, so R_out.w[2] = 2.0.
  // der(x) = 2.0, x(1) = 2.0.
  model RecordPassthroughSimple
    Vec3Passthrough pt;
    Real x(start = 0);
  equation
    pt.R_in.w = {1, 2, 3};
    der(x) = pt.R_out.w[2];
  end RecordPassthroughSimple;

  // ========================================================================
  // Tests for record-returning functions where the record has array fields.
  // This mimics MSL MultiBody Frames.absoluteRotation which returns an
  // Orientation record (T[3,3] + w[3]).
  // DAE pattern: ASUB(ASUB(CALL, [tupleIx]), [i, j, ...])
  // where inner ASUB extracts the field (treated as tuple element) and
  // outer ASUB indexes into the array field.
  // ========================================================================

  record MatrixRecord
    Real[3, 3] M;
    Real[3] v;
  end MatrixRecord;

  function makeMatrixRecord
    input Real a;
    input Real b;
    output MatrixRecord r;
  algorithm
    r.M := [a, 0, 0; 0, b, 0; 0, 0, 1];
    r.v := {a, b, a + b};
  end makeMatrixRecord;

  // Test D: 2D matrix field access from record-returning function with state args.
  // Exercises ASUB(ASUB(CALL, [1]), [1, 1]) - matrix element of first tuple element.
  // r.M = [2, 0, 0; 0, 3, 0; 0, 0, 1], so r.M[1,1] = 2, der(x) = 2, x(1) = 2.0.
  model MatrixRecordFuncAccess2D
    Real state(start = 2.0);
    MatrixRecord r;
    Real x(start = 0);
  equation
    der(state) = 0;
    r = makeMatrixRecord(state, 3.0);
    der(x) = r.M[1, 1];
  end MatrixRecordFuncAccess2D;

  // Test E: 1D vector field access from record-returning function with state args.
  // Exercises ASUB(ASUB(CALL, [2]), [1]) - vector element of second tuple element.
  // r.v = {2, 3, 5}, so r.v[1] = 2, der(y) = 2, y(1) = 2.0.
  model MatrixRecordFuncAccess1D
    Real state(start = 2.0);
    MatrixRecord r;
    Real y(start = 0);
  equation
    der(state) = 0;
    r = makeMatrixRecord(state, 3.0);
    der(y) = r.v[1];
  end MatrixRecordFuncAccess1D;

end RecordFunctionTest;
