model TableEdgeBlocks "a BooleanTable into the MSL edge and change blocks (OpenModelica: nRise = 2, nChange = 3 at 1)"
  Modelica.Blocks.Sources.BooleanTable tab(table = {0.2, 0.4, 0.7});
  Modelica.Blocks.MathBoolean.RisingEdge rising;
  Modelica.Blocks.Logical.Change change1;
  discrete Integer nRise(start = 0, fixed = true);
  discrete Integer nChange(start = 0, fixed = true);
  equation
  connect(tab.y, rising.u);
  connect(tab.y, change1.u);
  when rising.y then nRise = pre(nRise) + 1; end when;
  when change1.y then nChange = pre(nChange) + 1; end when;
end TableEdgeBlocks;
