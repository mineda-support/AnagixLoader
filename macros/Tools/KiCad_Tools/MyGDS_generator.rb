# KLayout Macro: Generated via SXP Parser (RBA Version)
module MyLayoutGenerator
  include RBA
  mw = Application.instance.main_window
  view = mw.current_view
  if view
    layout = view.active_cellview.layout
    top_cell = view.active_cellview.cell
    top_cell.clear
  else
    layout = Layout.new
    layout.dbu = 0.001
    top_cell = layout.create_cell("Ring_Oscillator_Top")
  end
  dbu = layout.dbu
  layers = {}
  layers["F.Cu"] = layout.layer(LayerInfo.new(6, 0))
  layers["B.Cu"] = layout.layer(LayerInfo.new(10, 0))
  layers["Via"]  = layout.layer(LayerInfo.new(9, 0))
  library = Library.library_by_name("PCells_PTS06")
  raise "Library 'PCells_PTS06' not found" unless library
  nch_decl = library.layout.pcell_declaration("Nch")
  pch_decl = library.layout.pcell_declaration("Pch")
  pch_pcell_id = layout.add_pcell_variant(library, pch_decl.id, { "w" => 10.0, "l" => 0.5, "m" => 1 })
  nch_pcell_id = layout.add_pcell_variant(library, nch_decl.id, { "w" => 5.0, "l" => 0.5, "m" => 1 })

  # --- U? (INV_X1_M_UD) ---
  base_x = 70.0 / dbu
  base_y = -97.4987 / dbu
  fp_trans = Trans.new(0.0, false, base_x.to_i, base_y.to_i)
  n_local = Trans.new(0, true,  0, (-15.0/dbu).to_i)
  p_local = Trans.new(0, true,  0, (-5.0/dbu).to_i)
  top_cell.insert(CellInstArray.new(nch_pcell_id, fp_trans * n_local))
  top_cell.insert(CellInstArray.new(pch_pcell_id, fp_trans * p_local))

  # --- U? (INV_X1_UD) ---
  base_x = 78.875 / dbu
  base_y = -97.4987 / dbu
  fp_trans = Trans.new(0.0, false, base_x.to_i, base_y.to_i)
  n_local = Trans.new(0, false, 0, (-15.0/dbu).to_i)
  p_local = Trans.new(0, false, 0, (-5.0/dbu).to_i)
  top_cell.insert(CellInstArray.new(nch_pcell_id, fp_trans * n_local))
  top_cell.insert(CellInstArray.new(pch_pcell_id, fp_trans * p_local))

  # --- U? (INV_X1) ---
  base_x = 61.375 / dbu
  base_y = -95.151 / dbu
  fp_trans = Trans.new(0.0, false, base_x.to_i, base_y.to_i)
  n_local = Trans.new(0, false, 0, 0)
  p_local = Trans.new(0, false, 0, (10.0/dbu).to_i)
  top_cell.insert(CellInstArray.new(nch_pcell_id, fp_trans * n_local))
  top_cell.insert(CellInstArray.new(pch_pcell_id, fp_trans * p_local))

  # --- U? (INV_X1) ---
  base_x = 78.875 / dbu
  base_y = -95.151 / dbu
  fp_trans = Trans.new(0.0, false, base_x.to_i, base_y.to_i)
  n_local = Trans.new(0, false, 0, 0)
  p_local = Trans.new(0, false, 0, (10.0/dbu).to_i)
  top_cell.insert(CellInstArray.new(nch_pcell_id, fp_trans * n_local))
  top_cell.insert(CellInstArray.new(pch_pcell_id, fp_trans * p_local))

  # --- U? (INV_X1_M_UD) ---
  base_x = 61.375 / dbu
  base_y = -97.4987 / dbu
  fp_trans = Trans.new(0.0, false, base_x.to_i, base_y.to_i)
  n_local = Trans.new(0, true,  0, (-15.0/dbu).to_i)
  p_local = Trans.new(0, true,  0, (-5.0/dbu).to_i)
  top_cell.insert(CellInstArray.new(nch_pcell_id, fp_trans * n_local))
  top_cell.insert(CellInstArray.new(pch_pcell_id, fp_trans * p_local))

  # --- U? (INV_X1) ---
  base_x = 70.0 / dbu
  base_y = -95.151 / dbu
  fp_trans = Trans.new(0.0, false, base_x.to_i, base_y.to_i)
  n_local = Trans.new(0, false, 0, 0)
  p_local = Trans.new(0, false, 0, (10.0/dbu).to_i)
  top_cell.insert(CellInstArray.new(nch_pcell_id, fp_trans * n_local))
  top_cell.insert(CellInstArray.new(pch_pcell_id, fp_trans * p_local))

  # --- U? (INV_X1) ---
  base_x = 52.575 / dbu
  base_y = -95.151 / dbu
  fp_trans = Trans.new(0.0, false, base_x.to_i, base_y.to_i)
  n_local = Trans.new(0, false, 0, 0)
  p_local = Trans.new(0, false, 0, (10.0/dbu).to_i)
  top_cell.insert(CellInstArray.new(nch_pcell_id, fp_trans * n_local))
  top_cell.insert(CellInstArray.new(pch_pcell_id, fp_trans * p_local))

  # --- U? (INV_X1_M_UD) ---
  base_x = 52.575 / dbu
  base_y = -97.4987 / dbu
  fp_trans = Trans.new(0.0, false, base_x.to_i, base_y.to_i)
  n_local = Trans.new(0, true,  0, (-15.0/dbu).to_i)
  p_local = Trans.new(0, true,  0, (-5.0/dbu).to_i)
  top_cell.insert(CellInstArray.new(nch_pcell_id, fp_trans * n_local))
  top_cell.insert(CellInstArray.new(pch_pcell_id, fp_trans * p_local))

  # --- 驟咲ｷ壽緒逕ｻ ---
  if layers["F.Cu"]
    p1 = Point.new((81.8/dbu).to_i, (-87.3/dbu).to_i)
    p2 = Point.new((80.3903/dbu).to_i, (-87.3/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((77.3825/dbu).to_i, (-105.0/dbu).to_i)
    p2 = Point.new((77.5/dbu).to_i, (-105.1175/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((81.8/dbu).to_i, (-105.1/dbu).to_i)
    p2 = Point.new((81.8/dbu).to_i, (-87.3/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((81.7825/dbu).to_i, (-105.1175/dbu).to_i)
    p2 = Point.new((81.8/dbu).to_i, (-105.1/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((80.3903/dbu).to_i, (-87.3/dbu).to_i)
    p2 = Point.new((80.3/dbu).to_i, (-87.2097/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((71.45/dbu).to_i, (-105.0/dbu).to_i)
    p2 = Point.new((77.3825/dbu).to_i, (-105.0/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((77.5/dbu).to_i, (-105.1175/dbu).to_i)
    p2 = Point.new((81.7825/dbu).to_i, (-105.1175/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((65.875/dbu).to_i, (-110.2/dbu).to_i)
    p2 = Point.new((68.275/dbu).to_i, (-110.2/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((65.875/dbu).to_i, (-105.4/dbu).to_i)
    p2 = Point.new((65.875/dbu).to_i, (-110.2/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((63.025/dbu).to_i, (-105.1/dbu).to_i)
    p2 = Point.new((65.975/dbu).to_i, (-105.1/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((83.6/dbu).to_i, (-83.3/dbu).to_i)
    p2 = Point.new((83.6/dbu).to_i, (-114.3/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((83.5497/dbu).to_i, (-83.2497/dbu).to_i)
    p2 = Point.new((83.6/dbu).to_i, (-83.3/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((83.6/dbu).to_i, (-114.3/dbu).to_i)
    p2 = Point.new((78.2/dbu).to_i, (-114.3/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((77.5/dbu).to_i, (-83.2497/dbu).to_i)
    p2 = Point.new((83.5497/dbu).to_i, (-83.2497/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((56.3/dbu).to_i, (-87.2/dbu).to_i)
    p2 = Point.new((56.3/dbu).to_i, (-92.3/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((54.0/dbu).to_i, (-87.2097/dbu).to_i)
    p2 = Point.new((56.2903/dbu).to_i, (-87.2097/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((56.2903/dbu).to_i, (-87.2097/dbu).to_i)
    p2 = Point.new((56.3/dbu).to_i, (-87.2/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((56.4/dbu).to_i, (-92.4/dbu).to_i)
    p2 = Point.new((56.3/dbu).to_i, (-92.3/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((57.0/dbu).to_i, (-92.5/dbu).to_i)
    p2 = Point.new((59.5/dbu).to_i, (-92.5/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((65.5903/dbu).to_i, (-87.2097/dbu).to_i)
    p2 = Point.new((65.6/dbu).to_i, (-87.2/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((65.8/dbu).to_i, (-92.5/dbu).to_i)
    p2 = Point.new((66.3/dbu).to_i, (-92.5/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((66.3322/dbu).to_i, (-92.5322/dbu).to_i)
    p2 = Point.new((68.625/dbu).to_i, (-92.5322/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((65.6/dbu).to_i, (-87.2/dbu).to_i)
    p2 = Point.new((65.8/dbu).to_i, (-87.4/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((65.8/dbu).to_i, (-87.4/dbu).to_i)
    p2 = Point.new((65.8/dbu).to_i, (-92.5/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((66.3/dbu).to_i, (-92.5/dbu).to_i)
    p2 = Point.new((66.3322/dbu).to_i, (-92.5322/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((62.8/dbu).to_i, (-87.2097/dbu).to_i)
    p2 = Point.new((65.5903/dbu).to_i, (-87.2097/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((74.3903/dbu).to_i, (-87.2097/dbu).to_i)
    p2 = Point.new((74.4/dbu).to_i, (-87.2/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((71.425/dbu).to_i, (-87.2097/dbu).to_i)
    p2 = Point.new((74.3903/dbu).to_i, (-87.2097/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((74.4/dbu).to_i, (-87.2/dbu).to_i)
    p2 = Point.new((74.4/dbu).to_i, (-92.4/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((74.4/dbu).to_i, (-92.4/dbu).to_i)
    p2 = Point.new((74.5322/dbu).to_i, (-92.5322/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((74.5322/dbu).to_i, (-92.5322/dbu).to_i)
    p2 = Point.new((77.5/dbu).to_i, (-92.5322/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((56.8/dbu).to_i, (-105.4175/dbu).to_i)
    p2 = Point.new((56.8/dbu).to_i, (-110.2175/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((53.95/dbu).to_i, (-105.1175/dbu).to_i)
    p2 = Point.new((56.9/dbu).to_i, (-105.1175/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((56.8/dbu).to_i, (-110.2175/dbu).to_i)
    p2 = Point.new((59.2/dbu).to_i, (-110.2175/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((57.0/dbu).to_i, (-109.7799/dbu).to_i)
    p2 = Point.new((56.8/dbu).to_i, (-109.5799/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((56.9/dbu).to_i, (-109.8799/dbu).to_i)
    p2 = Point.new((57.0/dbu).to_i, (-109.7799/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((48.2/dbu).to_i, (-92.6/dbu).to_i)
    p2 = Point.new((48.2/dbu).to_i, (-110.8/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((48.2/dbu).to_i, (-110.8/dbu).to_i)
    p2 = Point.new((48.56/dbu).to_i, (-110.44/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((48.2678/dbu).to_i, (-92.5322/dbu).to_i)
    p2 = Point.new((48.2/dbu).to_i, (-92.6/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((51.2/dbu).to_i, (-92.5322/dbu).to_i)
    p2 = Point.new((48.2678/dbu).to_i, (-92.5322/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end
  if layers["F.Cu"]
    p1 = Point.new((48.56/dbu).to_i, (-110.44/dbu).to_i)
    p2 = Point.new((51.15/dbu).to_i, (-110.44/dbu).to_i)
    path = Path.new([p1, p2], (1.0/dbu).to_i)
    top_cell.shapes(layers["F.Cu"]).insert(path)
  end

  # --- 繝薙い謠冗判 ---
  if layers["Via"]
    v_size = (0.6/dbu).to_i
    cx = (71.375/dbu).to_i
    cy = (-100.6175/dbu).to_i
    box = Box.new(cx - v_size/2, cy - v_size/2, cx + v_size/2, cy + v_size/2)
    top_cell.shapes(layers["Via"]).insert(box)
  end
  if layers["Via"]
    v_size = (0.6/dbu).to_i
    cx = (77.5/dbu).to_i
    cy = (-97.0322/dbu).to_i
    box = Box.new(cx - v_size/2, cy - v_size/2, cx + v_size/2, cy + v_size/2)
    top_cell.shapes(layers["Via"]).insert(box)
  end
  if layers["Via"]
    v_size = (0.6/dbu).to_i
    cx = (51.2/dbu).to_i
    cy = (-97.0322/dbu).to_i
    box = Box.new(cx - v_size/2, cy - v_size/2, cx + v_size/2, cy + v_size/2)
    top_cell.shapes(layers["Via"]).insert(box)
  end
  if layers["Via"]
    v_size = (0.6/dbu).to_i
    cx = (62.75/dbu).to_i
    cy = (-100.6175/dbu).to_i
    box = Box.new(cx - v_size/2, cy - v_size/2, cx + v_size/2, cy + v_size/2)
    top_cell.shapes(layers["Via"]).insert(box)
  end
  if layers["Via"]
    v_size = (0.6/dbu).to_i
    cx = (53.95/dbu).to_i
    cy = (-100.6175/dbu).to_i
    box = Box.new(cx - v_size/2, cy - v_size/2, cx + v_size/2, cy + v_size/2)
    top_cell.shapes(layers["Via"]).insert(box)
  end
  if layers["Via"]
    v_size = (0.6/dbu).to_i
    cx = (68.625/dbu).to_i
    cy = (-97.0322/dbu).to_i
    box = Box.new(cx - v_size/2, cy - v_size/2, cx + v_size/2, cy + v_size/2)
    top_cell.shapes(layers["Via"]).insert(box)
  end
  if layers["Via"]
    v_size = (0.6/dbu).to_i
    cx = (77.5/dbu).to_i
    cy = (-100.6175/dbu).to_i
    box = Box.new(cx - v_size/2, cy - v_size/2, cx + v_size/2, cy + v_size/2)
    top_cell.shapes(layers["Via"]).insert(box)
  end
  if layers["Via"]
    v_size = (0.6/dbu).to_i
    cx = (60.0/dbu).to_i
    cy = (-97.0322/dbu).to_i
    box = Box.new(cx - v_size/2, cy - v_size/2, cx + v_size/2, cy + v_size/2)
    top_cell.shapes(layers["Via"]).insert(box)
  end

  # --- 髮ｻ貅舌Ξ繝ｼ繝ｫ(Zone)謠冗判 ---
  if layers["F.Cu"]
    pts = []
    pts << Point.new((47.2/dbu).to_i, (-84.1/dbu).to_i)
    pts << Point.new((47.2/dbu).to_i, (-79.1/dbu).to_i)
    pts << Point.new((83.7/dbu).to_i, (-79.1/dbu).to_i)
    pts << Point.new((83.7/dbu).to_i, (-84.0/dbu).to_i)
    pts << Point.new((47.2/dbu).to_i, (-84.0/dbu).to_i)
    poly = Polygon.new(pts)
    top_cell.shapes(layers["F.Cu"]).insert(poly)
  end
  if layers["F.Cu"]
    pts = []
    pts << Point.new((47.2/dbu).to_i, (-118.6/dbu).to_i)
    pts << Point.new((47.2/dbu).to_i, (-113.6/dbu).to_i)
    pts << Point.new((83.7/dbu).to_i, (-113.6/dbu).to_i)
    pts << Point.new((83.7/dbu).to_i, (-118.5/dbu).to_i)
    pts << Point.new((47.2/dbu).to_i, (-118.5/dbu).to_i)
    poly = Polygon.new(pts)
    top_cell.shapes(layers["F.Cu"]).insert(poly)
  end
  if layers["B.Cu"]
    pts = []
    pts << Point.new((83.5/dbu).to_i, (-101.1/dbu).to_i)
    pts << Point.new((47.4/dbu).to_i, (-101.1/dbu).to_i)
    pts << Point.new((47.4/dbu).to_i, (-99.6/dbu).to_i)
    pts << Point.new((47.6/dbu).to_i, (-99.6/dbu).to_i)
    pts << Point.new((47.6/dbu).to_i, (-96.5/dbu).to_i)
    pts << Point.new((83.6/dbu).to_i, (-96.5/dbu).to_i)
    pts << Point.new((83.6/dbu).to_i, (-96.9/dbu).to_i)
    pts << Point.new((83.5/dbu).to_i, (-96.9/dbu).to_i)
    poly = Polygon.new(pts)
    top_cell.shapes(layers["B.Cu"]).insert(poly)
  end
  output_path = "c:/tmp/ring_oscillator_output.gds"
  layout.write(output_path)
  puts "GDS successfully generated: #{output_path}"
  if view
    view.zoom_fit
  end
end
