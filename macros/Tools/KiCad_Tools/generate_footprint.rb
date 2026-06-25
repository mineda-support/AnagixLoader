# ====================================================================
# 【エラー修正・確定版】インバータ基板から4マクロ直接抽出生成スクリプト
# ====================================================================
require 'fileutils'

# S式(Lisp構造)を改行やインデント不問で完璧に配列化する関数
def parse_s_expression(str)
  tokens = str.scan(/[()]|"(?:[^"\\]|\\.)*"|[^\s()]+/ )
  stack = [[]]
  tokens.each do |token|
    case token
    when '('
      new_list = []
      stack.last << new_list
      stack << new_list
    when ')'
      stack.pop
    else
      val = token.start_with?('"') ? token[1...-1] : token
      stack.last << val
    end
  end
  stack.first.first
end

def write_footprint(file_path, cell_name, w, h, graphics, pads)
  s_expr =  "(footprint \"#{cell_name}\"\n"
  s_expr += "  (version 20240101)\n"
  s_expr += "  (generator \"KiCad_SXP_INV_Generator_Full_Fixed\")\n"
  s_expr += "  (layer \"F.Cu\")\n"
  s_expr += "  (descr \"Upper-level macro cell for Floorplan\")\n"
  s_expr += "  (fp_rect (start #{-w/2} #{-h/2}) (end #{w/2} #{h/2}) (stroke (width 0.1) (type solid)) (fill none) (layer \"F.Fab\"))\n"
  s_expr += graphics
  s_expr += pads
  s_expr += ")\n"
  File.write(file_path, s_expr)
end

def generate_inv_footprint_clean
  kicad_pcb_file = File.join(ENV['HOMEPATH']|| ENV['HOME'], 'Seafile/KiCad4LSI/Inv_X1', "Inv_X1.kicad_pcb")
  output_lib_dir = File.join(ENV['HOMEPATH']|| ENV['HOME'], 'Seafile/KiCad4LSI', "MyCustomLibrary.pretty") # 出力先ライブラリフォルダ
  
  unless File.exist?(kicad_pcb_file)
    puts "エラー: #{kicad_pcb_file} が見つかりません。"
    return
  end
  pcb_content = File.read(kicad_pcb_file)

  parsed_pcb = parse_s_expression(pcb_content)
  return if parsed_pcb.nil?

  x_coords, y_coords, mos_data, segments = [], [], [], []

  parsed_pcb.each do |node|
    next unless node.is_a?(Array)
    if node[0] == "footprint" && node[1] =~ /MyCustomLibrary:(Nch|Pch)/
      pcell_name = $1
      mos_x, mos_y = 0.0, 0.0
      polygons, pads = [], []
      node.each do |child|
        next unless child.is_a?(Array)
        if child[0] == "at"
          mos_x = child[1].to_f
          mos_y = child[2].to_f
        end
        polygons << child if child[0] == "fp_poly"
        pads << child if child[0] == "pad"
      end
      x_coords << mos_x; y_coords << mos_y
      mos_data << { name: pcell_name, x: mos_x, y: mos_y, polys: polygons, pads: pads }
    end
    if node[0] == "segment"
      s = node.find{|c| c.is_a?(Array) && c[0] == "start"}
      e = node.find{|c| c.is_a?(Array) && c[0] == "end"}
      if s && e
        x_coords << s[1].to_f << e[1].to_f; y_coords << s[2].to_f << e[2].to_f
        segments << { x1: s[1].to_f, y1: s[2].to_f, x2: e[1].to_f, y2: e[2].to_f }
      end
    end
  end

  if x_coords.empty?
    puts "エラー: 座標データを抽出できませんでした。"
    return
  end

  inv_cx = ((x_coords.min + x_coords.max) / 2.0).round(4)
  inv_cy = ((y_coords.min + y_coords.max) / 2.0).round(4)

  # --- 4パターンのグラフィックス構築 ---
  g_n, g_m, g_ud, g_mud = "", "", "", ""
  macro_ports = { "IN" => [], "OUT" => [], "VDD" => [], "VSS" => [] }

  mos_data.each do |m|
    mos_x, mos_y = m[:x], m[:y]
    m[:polys].each do |poly|
      pts_node = poly.find { |c| c.is_a?(Array) && c[0] == "pts" }
      layer_node = poly.find { |c| c.is_a?(Array) && c[0] == "layer" }
      layer = layer_node ? layer_node[1] : "F.SilkS"
      stroke_node = poly.find { |c| c.is_a?(Array) && c[0] == "stroke" }
      stroke_type = stroke_node ? (stroke_node.find { |c| c.is_a?(Array) && c[0] == "type" } ? stroke_node.find { |c| c.is_a?(Array) && c[0] == "type" }[1] : "solid") : "solid"
      fill_node = poly.find { |c| c.is_a?(Array) && c[0] == "fill" }
      fill_type = fill_node ? fill_node[1] : "none"
      next unless pts_node

      pt_n, pt_m, pt_ud, pt_mud = "", "", "", ""
      pts_node.each do |xy|
        next unless xy.is_a?(Array) && xy[0] == "xy"
        rx = (mos_x + xy[1].to_f - inv_cx).round(4)
        ry = (mos_y + xy[2].to_f - inv_cy).round(4)
        pt_n   += " (xy #{rx} #{ry})"
        pt_m   += " (xy #{-rx} #{ry})"
        pt_ud  += " (xy #{rx} #{-ry})"
        pt_mud += " (xy #{-rx} #{-ry})"
      end

      unless pt_n.empty?
        s_stroke = stroke_type.include?("dash") ? "dash" : "solid"
        s_fill   = fill_type.include?("yes") ? "solid" : "none"
        poly_fmt = "  (fp_poly (pts%s) (stroke (width 0.05) (type #{s_stroke})) (fill #{s_fill}) (layer \"#{layer}\"))\n"
        g_n   += sprintf(poly_fmt, pt_n)
        g_m   += sprintf(poly_fmt, pt_m)
        g_ud  += sprintf(poly_fmt, pt_ud)
        g_mud += sprintf(poly_fmt, pt_mud)
      end
    end

    # 💡 内部パッドの確実な座標回収処理
    m[:pads].each do |pad|
      pin_num = pad[1].to_s
      at_node = pad.find { |c| c.is_a?(Array) && c[0] == "at" }
      next unless at_node
      abs_pad_x = mos_x + at_node[1].to_f
      abs_pad_y = mos_y + at_node[2].to_f

      if m[:name] == "Nch"
        macro_ports["IN"]  << [abs_pad_x, abs_pad_y] if pin_num == "2"
        macro_ports["VSS"] << [abs_pad_x, abs_pad_y] if pin_num == "3"
      elsif m[:name] == "Pch"
        macro_ports["OUT"] << [abs_pad_x, abs_pad_y] if pin_num == "1"
        macro_ports["VDD"] << [abs_pad_x, abs_pad_y] if pin_num == "3"
      end
    end

    lx = (mos_x - inv_cx).round(4)
    ly = (mos_y - inv_cy).round(4)
    txt_fmt = "  (fp_text user \"#{m[:name]}\" (at %s %s 0) (layer \"F.Fab\") (effects (font (size 0.5 0.5) (thickness 0.08))))\n"
    g_n   += sprintf(txt_fmt, lx, ly + 2.5)
    g_m   += sprintf(txt_fmt, -lx, ly + 2.5)
    g_ud  += sprintf(txt_fmt, lx, -ly - 2.5)
    g_mud += sprintf(txt_fmt, -lx, -ly - 2.5)
  end

  segments.each do |seg|
    rx1, ry1 = (seg[:x1] - inv_cx).round(4), (seg[:y1] - inv_cy).round(4)
    rx2, ry2 = (seg[:x2] - inv_cx).round(4), (seg[:y2] - inv_cy).round(4)
    line_fmt = "  (fp_line (start %s %s) (end %s %s) (stroke (width 0.12) (type solid)) (layer \"F.SilkS\"))\n"
    g_n   += sprintf(line_fmt, rx1, ry1, rx2, ry2)
    g_m   += sprintf(line_fmt, -rx1, ry1, -rx2, ry2)
    g_ud  += sprintf(line_fmt, rx1, -ry1, rx2, -ry2)
    g_mud += sprintf(line_fmt, -rx1, -ry1, -rx2, -ry2)
  end

  # 💡【重要修正】二次元配列の計算バグ(NoMethodError)を完全に排除した平均値計算
  get_coord = lambda do |ports, key|
    pts = ports[key]
    return [0.0, 0.0] if pts.empty?
    xs = pts.map { |p| p[0].to_f }
    ys = pts.map { |p| p[1].to_f }
    [(xs.sum / pts.size).round(4), (ys.sum / pts.size).round(4)]
  end

  in_x, in_y   = get_coord.call(macro_ports, "IN")
  out_x, out_y = get_coord.call(macro_ports, "OUT")
  vdd_x, vdd_y = get_coord.call(macro_ports, "VDD")
  vss_x, vss_y = get_coord.call(macro_ports, "VSS")

  p_in_x, p_in_y   = (in_x - inv_cx).round(4), (in_y - inv_cy).round(4)
  p_out_x, p_out_y = (out_x - inv_cx).round(4), (out_y - inv_cy).round(4)
  p_vdd_x, p_vdd_y = (vdd_x - inv_cx).round(4), (vdd_y - inv_cy).round(4)
  p_vss_x, p_vss_y = (get_coord.call(macro_ports, "VSS")[0] - inv_cx).round(4), (get_coord.call(macro_ports, "VSS")[1] - inv_cy).round(4)

  inv_w = (x_coords.max - x_coords.min + 4.0).round(4)
  inv_h = (y_coords.max - y_coords.min + 4.0).round(4)

  # 各パターンの外部パッド文字列の精緻な構築
  pad_fmt = "  (pad \"1\" smd rect (at %s %s) (size 1.5 1.5) (layers \"F.Cu\" \"F.Paste\" \"F.Mask\"))\n" +
            "  (pad \"2\" smd rect (at %s %s) (size 1.5 1.5) (layers \"F.Cu\" \"F.Paste\" \"F.Mask\"))\n" +
            "  (pad \"3\" smd rect (at %s %s) (size 3.0 1.0) (layers \"F.Cu\" \"F.Paste\" \"F.Mask\"))\n" +
            "  (pad \"4\" smd rect (at %s %s) (size 3.0 1.0) (layers \"F.Cu\" \"F.Paste\" \"F.Mask\"))\n"

  pads_n   = sprintf(pad_fmt, p_in_x, p_in_y, p_out_x, p_out_y, p_vdd_x, p_vdd_y, p_vss_x, p_vss_y)
  pads_m   = sprintf(pad_fmt, -p_in_x, p_in_y, -p_out_x, p_out_y, -p_vdd_x, p_vdd_y, -p_vss_x, p_vss_y)
  pads_ud  = sprintf(pad_fmt, p_in_x, -p_in_y, p_out_x, -p_out_y, p_vdd_x, -p_vdd_y, p_vss_x, -p_vss_y)
  pads_mud = sprintf(pad_fmt, -p_in_x, -p_in_y, -p_out_x, -p_out_y, -p_vdd_x, -p_vdd_y, -p_vss_x, -p_vss_y)

  # ライブラリへの4ファイル同時保存
  Dir.mkdir(output_lib_dir) unless Dir.exist?(output_lib_dir)
  write_footprint("#{output_lib_dir}/INV_X1.kicad_mod", "INV_X1", inv_w, inv_h, g_n, pads_n)
  write_footprint("#{output_lib_dir}/INV_X1_M.kicad_mod", "INV_X1_M", inv_w, inv_h, g_m, pads_m)
  write_footprint("#{output_lib_dir}/INV_X1_UD.kicad_mod", "INV_X1_UD", inv_w, inv_h, g_ud, pads_ud)
  write_footprint("#{output_lib_dir}/INV_X1_M_UD.kicad_mod", "INV_X1_M_UD", inv_w, inv_h, g_mud, pads_mud)
  
  puts "● 成功: 配列インデックスバグを排除し、4バリエーションマクロを完璧に同時生成しました！"
end

generate_inv_footprint_clean
