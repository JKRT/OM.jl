/*
  Minimal reproducer for algorithmic.jl:847 Meta.parse bug.
  Pattern: array-of-components where component's algorithm references
  a component-local Real field. Flattened name `inner[i]_y_aux`
  was Meta.parse'd as `inner[i] * _y_aux` due to implicit-mul rule
  after `]`. Fix: emit Symbol(flatName) directly.
*/
package ArrayCompAlgFieldMinPkg
  model InnerAlg
    input Real x;
    output Real y;
    Real y_aux;
  algorithm
    y_aux := x + 1.0;
    y := 2.0 * y_aux;
  end InnerAlg;

  model ArrayCompAlgFieldMin
    InnerAlg inner[2];
    Real x0(start = 0.0);
    Real out_final;
  equation
    der(x0) = 0.0;
    inner[1].x = 1.0;
    inner[2].x = 2.0;
    out_final = inner[1].y + inner[2].y;
  end ArrayCompAlgFieldMin;
end ArrayCompAlgFieldMinPkg;
