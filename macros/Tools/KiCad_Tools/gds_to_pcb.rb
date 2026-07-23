# $description: KLayout to KiCad conversion
# $show-in-menu
# coding: utf-8
module GDStoPCB
class KiCadGenerator
  include RBA
  #include MinedaCommon
  include MinedaPCellCommonModule
  require 'securerandom'
  
  TARGET_CENTER_X = 150.0  # A4枠(297x210)のほぼ中央
  TARGET_CENTER_Y = 100.0  # A4枠(297x210)のほぼ中央
  SCALE = 1 # 200.0 
  
  def initialize layout, pretty_dir, layers
    @layout = layout
    @pretty_dir = pretty_dir
    @layers = layers
    @offset_x = 0.0
    @offset_y = 0.0
  end

  def generate_MX_footprints
    Dir.glob('*.kicad_mod') {|file|
      next unless file =~ /(\S+m[0-9]+)\.kicad_mod/
      new_fp_name = $1 + '_MX'
      mx_file = new_fp_name + '.kicad_mod'
      next if File.exist?(mx_file) && (File.mtime(mx_file) > File.mtime(file))

      content = File.read(file, encoding: 'utf-8')
      content.sub!(/^(\s*\(footprint\s+)"[^"]+"/) do
        "#{$1}\"#{new_fp_name}\""
      end
      content.sub!(/^(\s*\(fp_text value\s+)"[^"]+"/) do
        "#{$1}\"#{new_fp_name}\""
      end
      # (at X Y [ANGLE]) の X 座標を反転
      content.gsub!(/\(at\s+([\d.-]+)\s+([\d.-]+)(?:\s+([\d.-]+))?\)/) do
        x = -$1.to_f
        y = $2.to_f
        angle = $3 ? $3.to_f : 0.0
        # 左右反転すると、個々のパーツが持つ自身の回転角（アングル）も逆回転(符号反転)になります
        angle = (-angle) % 360
        angle_str = angle == 0.0 ? "" : " #{angle.round(4)}"
        "(at #{x.round(4)} #{y.round(4)}#{angle_str})"
      end
      # 直線やグラフィックの座標 (pts (xy X1 Y1) (xy X2 Y2)) などの X 座標を反転
      content.gsub!(/\(xy\s+([\d.-]+)\s+([\d.-]+)\)/) do
        x = -$1.to_f
        y = $2.to_f
        "(xy #{x.round(4)} #{y.round(4)})"
      end
      File.write(mx_file, content)
      puts "#{File.join @pretty_dir, mx_file} created"
    }
  end
  
  def centerize placement_data
    # 1. 元データの中心（重心）を計算する
    sum_x = 0.0
    sum_y = 0.0
    placement_data.each_value do |item|
      sum_x += item[0].to_f
      sum_y += item[1].to_f
    end
    current_center_x = sum_x / placement_data.size
    current_center_y = sum_y / placement_data.size

    # 2. 目標中央座標へ移動させるためのオフセット量を計算
    offset_x = TARGET_CENTER_X - (current_center_x * SCALE)
    offset_y = TARGET_CENTER_Y - (current_center_y * SCALE)
    [offset_x, offset_y]
  end
  
  def generate_footprints placement_data, offset_x, offset_y, lib_name
    # フットプリント（footprint）セクションの生成
    @offset_x = offset_x
    @offset_y = offset_y
    footprints_sexpr = ""

    placement_data.each_pair do |ref, item|
      #ref = item[0]        # 素子名 (e.g., M5)
      item.unshift ref
      x = item[1].to_f     # X座標
      y = item[2].to_f     # Y座標
      fp_name = item[3]    # フットプリント名 (e.g., Pch.M0l2.0w6.0m1)
      angle = item[4]
      # KiCadの座標系（通常はmm）。
      # 必要に応じてGDSの単位（μm等）からmmへのスケール変換（例: x * 0.001）をここで行ってください。
      pos_x = ((x * SCALE) + @offset_x).round(4)
      pos_y = ((y * SCALE) + @offset_y).round(4)

      uuid = SecureRandom.uuid
  
      fp_body = get_footprint_body(fp_name, ref)

      footprints_sexpr << "  (footprint \"#{lib_name}:#{fp_name}\" (at #{pos_x} #{pos_y} #{angle}) (layer \"F.Cu\")\n"
      footprints_sexpr << "    (tstamp \"#{uuid}\")\n"
      footprints_sexpr << "    (at #{pos_x} #{pos_y})\n"
      footprints_sexpr << "    (descr \"Generated from KLayout PCell\")\n"
      footprints_sexpr << "    (property \"Reference\" \"#{ref}\" (at 0 -1 0) (layer \"F.SilkS\")\n"
      footprints_sexpr << "      (effects (font (size 1 1) (thickness 0.15)))\n"
      footprints_sexpr << "    )\n"
      footprints_sexpr << "    (property \"Value\" \"#{fp_name}\" (at 0 1 0) (layer \"F.Fab\")\n"
      footprints_sexpr << "      (effects (font (size 1 1) (thickness 0.15)))\n"
      footprints_sexpr << "    )\n"
  
      footprints_sexpr << fp_body
      footprints_sexpr << "  )\n\n"
    end
    footprints_sexpr
  end
  
    # フットプリントファイル(.kicad_mod)から中身（形状部分）を抽出する関数
  def get_footprint_body(fp_name, ref)
    mod_path = File.join(@pretty_dir, "#{fp_name}.kicad_mod")
    return "" unless File.exist?(mod_path)

    lines = File.read(mod_path)
    lines.sub!(/fp_text reference \"\S+\"/, "fp_text reference \"#{ref}\"")
    # 最初の行 (footprint ...) と最後の行 ) を除いた、中身の行だけを結合する
    body_lines = lines.split("\n")[1...-1]
    body_lines ? body_lines.join("\n"): ""
  end

  def write_pcb footprints, segments, pcb_file
    File.write(pcb_file, <<EOF
(kicad_pcb
	(version 20260206)
	(generator "pcbnew")
	(generator_version "10.0")
	(general
		(thickness 1.6)
		(legacy_teardrops no)
	)
	(paper "A4")
	(layers
		(0 "F.Cu" signal)
		(2 "B.Cu" signal)
		(9 "F.Adhes" user "F.Adhesive")
		(11 "B.Adhes" user "B.Adhesive")
		(13 "F.Paste" user)
		(15 "B.Paste" user)
		(5 "F.SilkS" user "F.Silkscreen")
		(7 "B.SilkS" user "B.Silkscreen")
		(1 "F.Mask" user)
		(3 "B.Mask" user)
		(17 "Dwgs.User" user "User.Drawings")
		(19 "Cmts.User" user "User.Comments")
		(21 "Eco1.User" user "User.Eco1")
		(23 "Eco2.User" user "User.Eco2")
		(25 "Edge.Cuts" user)
		(27 "Margin" user)
		(31 "F.CrtYd" user "F.Courtyard")
		(29 "B.CrtYd" user "B.Courtyard")
		(35 "F.Fab" user)
		(33 "B.Fab" user)
	)
	(setup
		(pad_to_mask_clearance 0)
		(allow_soldermask_bridges_in_footprints no)
		(tenting
			(front yes)
			(back yes)
		)
		(covering
			(front no)
			(back no)
		)
		(plugging
			(front no)
			(back no)
		)
		(capping no)
		(filling no)
		(pcbplotparams
			(layerselection 0x00000000_00000000_55555555_5755f5ff)
			(plot_on_all_layers_selection 0x00000000_00000000_00000000_00000000)
			(disableapertmacros no)
			(usegerberextensions no)
			(usegerberattributes yes)
			(usegerberadvancedattributes yes)
			(creategerberjobfile yes)
			(dashed_line_dash_ratio 12)
			(dashed_line_gap_ratio 3)
			(svgprecision 4)
			(plotframeref no)
			(mode 1)
			(useauxorigin no)
			(pdf_front_fp_property_popups yes)
			(pdf_back_fp_property_popups yes)
			(pdf_metadata yes)
			(pdf_single_document no)
			(dxfpolygonmode yes)
			(dxfimperialunits yes)
			(dxfusepcbnewfont yes)
			(psnegative no)
			(psa4output no)
			(plot_black_and_white yes)
			(sketchpadsonfab no)
			(plotpadnumbers no)
			(hidednponfab no)
			(sketchdnponfab yes)
			(crossoutdnponfab yes)
			(subtractmaskfromsilk no)
			(outputformat 1)
			(mirror no)
			(drillshape 1)
			(scaleselection 1)
			(outputdirectory "")
		)
	)
      #{footprints}
      #{segments}
	(embedded_fonts no)
)
EOF
  )
  end
  
  def generate_kicad_box inst, box, layer='F.Cu', trans
    name = inst.cell.name
    x = trans*inst.trans.disp.x
    y = trans*inst.trans.disp.y
    segment = <<EOF
        (footprint "#{name}" (layer "#{layer}") (at 0 0)
            (pad "" smd rect 
                (at #{(x*@layout.dbu+@offset_x).round(4)} #{(-y*@layout.dbu+@offset_y).round(4)}) 
                (size #{(box.width*@layout.dbu).round(4)} #{(box.height*@layout.dbu).round(4)})
                (layers "#{layer}") (net 0 "")
            )
        )        
EOF
    segment
  end
      
  #MAX_PATH_WIDTH = 5
  def generate_net_rail_pad_for_BOX box, layer_name='F.Cu'
    x = box.center.x*@layout.dbu
    y = -box.center.y*@layout.dbu
    segment = <<EOF
(footprint "Net_Rail_Pad_for_BOX" (layer "#{layer_name}") (at 0 0)
    (pad "" smd rect 
        (at #{(x+@offset_x).round(4)} #{(y+@offset_y).round(4)}) 
        (size #{(box.width*@layout.dbu).round(4)} #{(box.height*@layout.dbu).round(4)})
        (layers "#{layer_name}") (net 0 "")
     )
)        
EOF
    segment
  end

  def complex_path_to_kicad_pads path, net_name, layer='F.Cu'
    # Pathの太さ（幅）をmmに変換
    width_mm = path.width * @layout.dbu
  
    # ネット名・ネット情報の取得
    net_name ||= ""
    net_id = (net_name == "" || net_name.nil?) ? 0 : 1
    net_name_str = net_name.nil? ? "" : net_name.to_s

# 1. Pathの全頂点を配列に格納 (ここではKLayoutの生の座標(mm)のまま保持)
    points = []
    path.each_point do |p|
      points << [p.x, p.y]
    end
  
    kicad_pads = "(footprint \"Net_Rail_Pad\" (layer \"#{layer}\") (at 0 0)\n"
  
  # 2. each_cons(2) で2点ずつ直接取り出す
    points.each_cons(2) do |p1, p2|

      # KLayoutの座標系のままで中心座標(at)を計算
      center_x = (p1[0] + p2[0]) / 2.0
      center_y = (p1[1] + p2[1]) / 2.0 

      # 線分自体の長さを計算
      length = Math.sqrt((p2[0] - p1[0])**2 + (p2[1] - p1[1])**2) * @layout.dbu

      # 水平（H）か垂直（V）かでサイズを割り振る (KLayout座標のままなので素直に比較できます)
      if (p1[1] - p2[1]).abs < 0.0001
        size_w = length
        size_h = width_mm
      else
        size_w = width_mm
        size_h = length
      end
      # 3. KiCadの footprint / pad 形式で1セグメントずつ出力
      kicad_pads << <<EOF
      (pad "" smd rect
            (at #{(center_x*@layout.dbu + @offset_x).round(4)} #{(-center_y*@layout.dbu + @offset_y).round(4)})
            (size #{size_w} #{size_h})
            (layers "#{layer}")
            (net #{net_id} "#{net_name_str}")
       )
EOF
    end
    kicad_pads << ")\n"
    kicad_pads
  end
  
  def convert_pcells_to_kicad_mods cell, trans = Trans::R0
    kicad_elements = {}
    count = 0
    segments = ''
    cell.each_inst{|inst|
    #top_cell.begin_instances_rec.each{|iter|
    #  inst = iter.inst_cell
      puts "#{inst.cell.name}(#{inst.property('name')}): #{(trans*inst.trans).to_s}"
      if inst.is_pcell?
        l=inst.pcell_parameter 'l'
        w=inst.pcell_parameter('w') || 2.0
        m=inst.pcell_parameter('n') || 0
        next unless l && w
        rot = (trans*inst.trans).to_s.sub(/ .*$/, '').upcase
        kicad_cell_name = "#{inst.cell.name.sub(/\$.*$/,'')}.l#{l.round(4)}w#{w.round(4)}m#{m||0}"
        kicad_cell_name << '_MX' if rot.start_with? 'M'

        infile = File.join(@pretty_dir, kicad_cell_name) + '.kicad_mod'
        if File.exist?(infile)
          count = count + 1
          name = inst.property('name') || inst.cell.name.sub(/\$.*$/,'')+count.to_s        
          angle = case rot
                when 'R0'     then 0
                when 'R90'    then 90
                when 'R180'   then 180
                when 'R270'   then 270
                when 'M0'     then 180
                when 'M45'    then 90
                when 'M90'    then 0
                when 'M135'   then 270
                else
                  warn "未知の変換指示です: #{rot}"
                  0
                end         
          kicad_elements[name] = [((trans*inst.trans).disp.x*@layout.dbu).round(4), (-(trans*inst.trans).disp.y*@layout.dbu).round(4), 
                                  kicad_cell_name, angle]
        else
          puts "#{infile} does not exist!"
        end
      #elsif 
      else
        k_e = convert_pcells_to_kicad_mods inst.cell, trans*inst.trans
        kicad_elements.merge! k_e
      end
    }
    kicad_elements
  end
  
  def convert_paths_and_cells_to_kicad_segments cell, trans = Trans::R0
    segments = ''
    cell.each_inst{|inst|
      if inst.is_pcell?
        next
      elsif inst.cell.name.sub(/\$.*$/, '') == 'Via'
        # puts "Missing cell is : #{inst.cell.name}"
        width = inst.cell.bbox.width*@layout.dbu
        inst.cell_inst.each_trans{|trans|
          segments << <<EOF + "\n"
      (via
     	    (at #{(trans.disp.x*@layout.dbu+@offset_x).round(4)} #{(-(trans.disp.y)*@layout.dbu+@offset_y).round(4)})
		(size #{width})
		(drill #{width/2})
		(layers "F.Cu" "B.Cu")
		(net "")
		(uuid "#{SecureRandom.uuid}")
      )
EOF
        }
      elsif inst.cell.is_library_cell?
        puts "Cell: #{inst.cell.name}"
        inst.cell.shapes(@layers['F.Cu']).each{|shape|
          segments << generate_kicad_box(inst, shape.bbox, 'F.Cu', trans)
        }
     else
        seg = convert_paths_and_cells_to_kicad_segments inst.cell, trans*inst.trans
        segments << seg
      end 
    }  
 
    @layers.each_pair do |pcb_layer_name, layer|@off
      cell.shapes(layer).each{|shape|
        if shape.is_path?
          #if shape.path.width*@layout.dbu > MAX_PATH_WIDTH

          pads = complex_path_to_kicad_pads(trans*shape.path, shape.property('name'), pcb_layer_name) 
          segments << pads if pads
          #end 
        elsif shape.is_box?
          segments << generate_net_rail_pad_for_BOX(trans*shape.box, pcb_layer_name)
        end
      }
    end
    segments
  end

  
  mw = Application.instance.main_window
  view = mw.current_view
  if view
    layout = view.active_cellview.layout
    top_cell = view.active_cellview.cell
    #  top_cell = layout.cell("TOP") || layout.create_cell("TOP")
  else
    layout = Layout.new
    layout.dbu = 0.001
    top_cell = layout.create_cell(gds_file)
  end
  fp_lib_table_file = top_cell.property('fp-lib-table')
  if fp_lib_table_file && File.exist?(fp_lib_table_file)
    require 'sxp'
    fp_lib_table = File.read(fp_lib_table_file)
    puts 'fp_lib_table:', fp_lib_table.inspect
    flt = SXP.read(fp_lib_table)
    lib = flt.assoc(:lib)
    pretty_lib = lib.assoc(:name)[1]
    pretty_dir = lib.assoc(:uri)[1]
  else
    pretty_lib = top_cell.property('pretty_lib')
    pretty_dir = top_cell.property('pretty_dir')
    if pretty_lib.nil?
      pretty_dir = File.dirname(view.active_cellview.filename)
      pretty_lib = File.basename(pretty_dir).sub(File.extname(pretty_dir), '')
    end
  end
  puts "Execute GDS to PCB conversion at pretty_dir=#{pretty_dir}"
  
  filename = view.active_cellview.filename 
  pcb_file = File.join(File.dirname(filename), File.basename(filename).sub(File.extname(filename), '') + '.kicad_pcb')
  mpc = MinedaPCellCommon.new
  mpc.set_technology(view ? view.active_cellview.technology : "")
  mpc.set_layer_index
  layers = {}
  begin
    layers["F.Cu"] = layout.layer(mpc.get_layer_index('ML1', false), 0)
    layers["B.Cu"] = layout.layer(mpc.get_layer_index('ML2', false), 0)
    layers["Via"]  = layout.layer(mpc.get_layer_index('VIA1', false), 0)
  rescue => e
    puts "Layer setup error: #{e.message}"
    exit
  end
  pcell_lib = ('PCells_' + view.active_cellview.technology).sub('PCells_OpenRule1um', 'PCells')
  library = Library.library_by_name(pcell_lib)
  raise "Library '#{pcell_lib}' not found" unless library
  kc = KiCadGenerator.new layout, pretty_dir, layers
  Dir.chdir(pretty_dir){
    kc.generate_MX_footprints
  }
  kicad_elements, segments = kc.convert_pcells_to_kicad_mods top_cell

  puts kicad_elements.inspect
  offset_x, offset_y = kc.centerize kicad_elements
  footprints = kc.generate_footprints kicad_elements, offset_x, offset_y, pcell_lib
  segments = kc.convert_paths_and_cells_to_kicad_segments top_cell
  kc.write_pcb footprints, segments, pcb_file
  puts "KiCad PCB successfully generated: #{pcb_file}"
end
end