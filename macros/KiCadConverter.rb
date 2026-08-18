# coding: utf-8
module KiCadConverter
class KiCadGenerator
  include RBA
  #include MinedaCommon
  #include MinedaPCellCommonModule
  require 'securerandom'
  
  TARGET_CENTER_X = 150.0  # A4枠(297x210)のほぼ中央
  TARGET_CENTER_Y = 100.0  # A4枠(297x210)のほぼ中央
  SCALE = 1 # 200.0 
  
  def initialize layout, pretty_dir, layers, lvs_data, ml1, ml2
    @layout = layout
    @pretty_dir = pretty_dir
    @layers = layers
    @offset_x = 0.0
    @offset_y = 0.0
    if @lvs_data = lvs_data
      cross_ref = lvs_data.xref
      netlist = @lvs_data.netlist
      @sch_to_dev_map = {}

      netlist.each_circuit do |circuit|
        cross_ref.each_device_pair(circuit) do |pair|
          dev_layout = pair.first
          dev_ref = pair.second
          next unless dev_layout && dev_ref
          center = RBA::ICplxTrans::new(dev_layout.trans, @layout.dbu).disp
          prefix = find_prefix dev_layout.device_class.class.name
          name_ref = prefix + (dev_ref.expanded_name.empty? ? dev_ref.name : dev_ref.expanded_name)
          @sch_to_dev_map[name_ref] = center 
        end
      end
    end
    @ml1 = ml1
    @ml2 = ml2
  end
  
  def find_prefix device_class_name
    prefix = nil
    case device_class_name
    when 'RBA::DeviceClassResistor', 'RBA::DeviceClassResistorWithBulk'
      prefix = 'R'
    when 'RBA::DeviceClassCapacitor', 'RBA::DeviceClassCapacitorWithBulk'
      prefix = 'C'
    when 'RBA::DeviceClassDiode'
      prefix = 'D'
    when 'RBA::DeviceClassMOS3Transistor', 'RBA::DeviceClassMOS4Transistor'
      prefix = 'M'
    when 'RBA::DeviceClassBJT3Transistor', 'RBA::DeviceClassBJT4Transistor'
      prefix = 'Q' 
    end
    prefix
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
        angle_str = angle == 0.0 ? "" : " #{angle.round(2)}"
        "(at #{x.round(2)} #{y.round(2)}#{angle_str})"
      end
      # 直線やグラフィックの座標 (pts (xy X1 Y1) (xy X2 Y2)) などの X 座標を反転
      content.gsub!(/\(xy\s+([\d.-]+)\s+([\d.-]+)\)/) do
        x = -$1.to_f
        y = $2.to_f
        "(xy #{x.round(2)} #{y.round(2)})"
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
      pos_x = ((x * SCALE) + @offset_x).round(2)
      pos_y = ((y * SCALE) + @offset_y).round(2)

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
                (at #{(x*@layout.dbu+@offset_x).round(2)} #{(-y*@layout.dbu+@offset_y).round(2)}) 
                (size #{(box.width*@layout.dbu).round(2)} #{(box.height*@layout.dbu).round(2)})
                (layers "#{layer}") (net 0 "")
            )
        )        
EOF
    segment
  end
      
  def generate_contact name, box, layer_name='F.Cu'
    x = box.center.x*@layout.dbu+@offset_x
    y = -box.center.y*@layout.dbu+@offset_y
    width = box.width*@layout.dbu
    height = box.height*@layout.dbu
    x1, y1 = [x - width/2, y - height/2]
    x2, y2 = [x + width/2, y + height/2]
    segment = <<EOF
(footprint "#{name}" (layer "#{layer_name}") (at 0 0)
     (fp_poly (pts (xy #{x1.round(2)} #{y1.round(2)}) (xy #{x1.round(2)} #{y2.round(2)})
                   (xy #{x2.round(2)} #{y2.round(2)}) (xy #{x2.round(2)} #{y1.round(2)}))
         (stroke (width 0.05) (type solid)) (fill none) (layer \"#{layer_name}\")
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
        (at #{(x+@offset_x).round(2)} #{(y+@offset_y).round(2)}) 
        (size #{(box.width*@layout.dbu).round(2)} #{(box.height*@layout.dbu).round(2)})
        (layers "#{layer_name}") (net 0 "")
     )
)        
EOF
    segment
  end
  
  def polygon_points polygon
    points = ''
    polygon && polygon.each_point_hull{|e|
      points << " (xy #{(e.x*@layout.dbu+@offset_x).round(2)} #{(-e.y*@layout.dbu+@offset_y).round(2)})"
    }
    points
  end
  private :polygon_points
  
  def generate_zone polygon, filled_polygon, net_name, layer_name='F.Cu'
    polygon ||= filled_polygon
    segment = <<EOF
(zone
    (net "#{net_name}") (layer "#{layer_name}")
    (uuid #{SecureRandom.uuid})
    (hatch edge 0.5)
    (connect_pads yes
    (clearance 0.5)
    )
    (min_thickness 0.25)
    (fill yes
        (thermal_gap 0.5)
        (thermal_bridge_width 0.5)
        (island_removal_mode 0)
    )
    (polygon
        (pts
	  #{polygon_points polygon}
        )
    )
    (filled_polygon
        (layer "#{layer_name}")
        (pts
	  #{polygon_points filled_polygon}
        )
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
  
    #kicad_pads = "(footprint \"Net_Rail_Pad\" (layer \"#{layer}\") (at 0 0)\n"
    kicad_pads = ""
  
  # 2. each_cons(2) で2点ずつ直接取り出す
    pp = nil
    # puts "points = #{points}"
    points.each_cons(2) do |p1, p2|
      # puts "p1, p2, pp = #{[p1, p2, pp]}"
=begin
      # KLayoutの座標系のままで中心座標(at)を計算
      center_x = (p1[0] + p2[0]) / 2.0
      center_y = (p1[1] + p2[1]) / 2.0 

      # 線分自体の長さを計算
      length = Math.sqrt((p2[0] - p1[0])**2 + (p2[1] - p1[1])**2) * @layout.dbu

      # 水平（H）か垂直（V）かでサイズを割り振る (KLayout座標のままなので素直に比較できます)
      if (p1[1] - p2[1]).abs < 0.0001
        size_w = length
        size_h = width_mm
        if p1 == pp
          size_w = size_w + width_mm/1
          if p1[0] > p2[0]
            center_x = center_x + width_mm/2
          else
            center_x = center_x - width_mm/2
          end
        end
      else
        size_w = width_mm
        size_h = length
        if p1 == pp
          size_h = size_h + width_mm/1
          if p1[1] > p2[1]
            center_y = center_y + width_mm/2
          else
            center_y = center_y - width_mm/2
          end
        end
      end
      # 3. KiCadの footprint / pad 形式で1セグメントずつ出力

      kicad_pads << <<EOF
      (pad "" smd rect
            (at #{(center_x*@layout.dbu + @offset_x).round(2)} #{(-center_y*@layout.dbu + @offset_y).round(2)})
            (size #{size_w} #{size_h})
            (layers "#{layer}")
            (net #{net_id} "#{net_name_str}")
       )
EOF
=end
      kicad_pads << <<EOF
      (segment
          (start #{(p1[0]*@layout.dbu + @offset_x).round(2)} #{(-p1[1]*@layout.dbu + @offset_y).round(2)})
          (end #{(p2[0]*@layout.dbu + @offset_x).round(2)} #{(-p2[1]*@layout.dbu + @offset_y).round(2)})
          (width #{width_mm})
          (layer "#{layer}")
          (net "#{net_name_str}")
          (uuid #{SecureRandom.uuid})
       )
EOF
      pp = p2
    end
    #kicad_pads << ")\n"
    kicad_pads
  end
  
  def find_dev_name box
    puts "== x:#{[box.left,box.right]} y:#{[box.bottom,box.top]} =================="
    @sch_to_dev_map.each{|dev_name, point|
      #puts "#{dev_name}@[#{point.x}, #{point.y}]:#{point.x < box.left|| box.right < point.x}|#{point.y < box.bottom || box.top < point.y}"
      next if point.x < box.left|| box.right < point.x
      next if point.y < box.bottom || box.top < point.y
      puts "#{dev_name}@[#{point.x}, #{point.y}]:#{point.x < box.left|| box.right < point.x}|#{point.y < box.bottom || box.top < point.y}"
      puts "===========> #{dev_name}"
      return dev_name
    }
    puts 'fail!!! =================================='
    nil
  end  
  
  def convert_pcells_to_kicad_mods cell, trans = Trans::R0
    kicad_elements = {}
    count = 0
    segments = ''
    cell.each_inst{|inst|
    #top_cell.begin_instances_rec.each{|iter|
    #  inst = iter.inst_cell
      puts "#{inst.cell.name}(#{inst.property('name') || inst.property(1)}): #{(trans*inst.trans).to_s}"
      if inst.is_pcell?
        l=inst.pcell_parameter 'l'
        w=inst.pcell_parameter('w') || 2.0
        m=inst.pcell_parameter('n') || 0
        next unless l && w
        rot = (trans*inst.trans).to_s.sub(/ .*$/, '').upcase
        kicad_cell_name = "#{inst.cell.name.sub(/\$.*$/,'')}.l#{l.round(2)}w#{w.round(2)}m#{m||0}"
        kicad_cell_name << '_MX' if rot.start_with? 'M'

        infile = File.join(@pretty_dir, kicad_cell_name) + '.kicad_mod'
        if File.exist?(infile)
          count = count + 1
          if @lvs_data
            name = find_dev_name trans*inst.bbox         
          else
            name = inst.property('name') || inst.property(1) || inst.cell.name.sub(/\$.*$/,'')+count.to_s        
          end
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
          #kicad_elements[name] = [((trans*inst.trans).disp.x*@layout.dbu).round(2), (-(trans*inst.trans).disp.y*@layout.dbu).round(2), 
          #                        kicad_cell_name, angle]
          inst.cell_inst.each_trans{|trans2|
            kicad_elements[name] = [((trans*trans2).disp.x*@layout.dbu).round(2), (-((trans*trans2).disp.y)*@layout.dbu).round(2), 
                                  kicad_cell_name, angle]
          }
        else
          puts "#{infile} does not exist!"
        end
      elsif inst.is_regular_array?

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
        if @lvs_data
          
        else
          net_name = inst.property('net') || inst.property(1)
        end
        width = inst.cell.bbox.width*@layout.dbu
        drill_width = inst.cell.each_shape(@layers['Via']).first.bbox.width*@layout.dbu
        inst.cell_inst.each_trans{|trans|
          segments << <<EOF + "\n"
(via
   (at #{(trans.disp.x*@layout.dbu+@offset_x).round(2)} #{(-(trans.disp.y)*@layout.dbu+@offset_y).round(2)})
       (size #{width}) (drill #{drill_width}) (layers "F.Cu" "B.Cu") (net "#{net_name}")
      	(uuid "#{SecureRandom.uuid}")
)
EOF
        }
      elsif inst.cell.is_library_cell?
        puts "Cell: #{inst.cell.name}"
        if ['pcont', 'psubcont', 'nsubcont'].include?(inst.cell.name.sub(/\$.*$/, ''))
          inst.cell_inst.each_trans{|trans|
            segments << generate_contact(inst.cell.name, trans*inst.cell.bbox, 'F.Fab')
          }
        else
        inst.cell.shapes(@layers['F.Cu']).each{|shape|
          segments << generate_kicad_box(inst, shape.bbox, 'F.Cu', trans)
        }
        end
     else
        seg = convert_paths_and_cells_to_kicad_segments inst.cell, trans*inst.trans
        segments << seg
      end 
    }  
 
    @layers.each_pair do |pcb_layer_name, layer|
      polygon = {}
      cell.shapes(layer).each{|shape|
        if shape.is_path?
          if @lvs_data
            probe_point = shape.path.polygon.point_hull(0)
            net_name = @lvs_data.probe_net(@ml1.data, probe_point) || @lvs_data.probe_net(@ml2.data, probe_point)
          else
            net_name = shape.property('net') || shape.property(1)
          end
          if shape.path.width > 10.0
            segments << generate_zone(polygon[net_name], trans*shape.polygon, net_name, pcb_layer_name)
          else
            puts "Shape width for #{net_name} is: #{shape.path.width}"
            pads = complex_path_to_kicad_pads(trans*shape.path, net_name, pcb_layer_name) 
            segments << pads if pads
          end
          #end 
        elsif shape.is_box?
          if @lvs_data
            probe_point = shape.box.center
            net_name = @lvs_data.probe_net(@ml1.data, probe_point) || @lvs_data.probe_net(@ml2.data, probe_point)
          else
            net_name = shape.property('net') || shape.property(1)
          end
          if polygon[net_name] # polygon with 4 points could be converted to box when saved and reload
            segments << generate_zone(polygon[net_name], trans*shape.polygon, net_name, pcb_layer_name)
          else
            segments << generate_net_rail_pad_for_BOX(trans*shape.box, pcb_layer_name)
          end
        elsif shape.is_polygon?
          if @lvs_data
            probe_point = shape.polygon.point_hull(0)
            net_name = @lvs_data.probe_net(@ml1.data, probe_point) || @lvs_data.probe_net(@ml2.data, probe_point)
          else
            net_name = shape.property('net') || shape.property(1)
          end
          if polygon[net_name] # shape.polygon is filled_polygon in zone
            segments << generate_zone(polygon[net_name], trans*shape.polygon, net_name, pcb_layer_name)
          else # trick to save polygon
            polygon[net_name] =  trans*shape.polygon
          end
        end
      }
    end
    segments
  end

def annotate_lvs_properties(lvs_data) # created with gemini help but no longer used
      cross_ref = lvs_data.xref
      netlist = lvs_data.netlist

      rdb = RBA::ReportDatabase.new("LVS_Annotation_Result")
      rdb.description = "LVS Net and Ref Annotations"

      view = RBA::LayoutView.current
      cv = view ? view.active_cellview : nil

      if cv && cv.is_valid?
        rdb.original_file = cv.filename
        top_cell_name = cv.cell ? cv.cell.name : "TOP"
      else
        top_cell_name = lvs_data.original_top_cell ? lvs_data.original_top_cell.name : "TOP"
      end

      rdb_cell = rdb.create_cell(top_cell_name)
      cat_net = rdb.create_category("Net_Names")
      cat_ref = rdb.create_category("Schematic_Refs")

      # --- A. 回路図 Ref マッピング ---
      dev_to_sch_name_map = {}

      netlist.each_circuit do |circuit|
        cross_ref.each_device_pair(circuit) do |pair|
          dev_layout = pair.first
          dev_ref = pair.second
          next unless dev_layout && dev_ref

          name_layout = dev_layout.expanded_name.empty? ? dev_layout.name : dev_layout.expanded_name
          name_ref    = dev_ref.expanded_name.empty? ? dev_ref.name : dev_ref.expanded_name

          dev_to_sch_name_map[name_layout] = name_ref unless name_layout.empty?
          dev_to_sch_name_map[dev_layout.name] = name_ref unless dev_layout.name.empty?
        end
      end

      # --- B. マーカー生成 ---
      layer_indices = lvs_data.layer_indexes
      item_count = 0

      netlist.each_circuit do |circuit|
        # 1. ネット名
        circuit.each_net do |net|
          net_name = net.expanded_name.empty? ? net.name : net.expanded_name
          next if net_name.nil? || net_name.empty?

          sub_cat = rdb.create_category(cat_net, net_name)

          layer_indices.each do |ly_idx|
            layer_region = lvs_data.layer_by_index(ly_idx)
            next if layer_region.nil?

            net_region = lvs_data.shapes_of_net(net, layer_region)
            next if net_region.nil? || net_region.is_empty?

            net_region.each do |poly|
              item = rdb.create_item(rdb_cell, sub_cat)
              item.add_value(poly)
              item_count += 1
            end
          end
        end

        # 2. デバイス Ref 名
        circuit.each_device do |device|
          dev_name = device.expanded_name.empty? ? device.name : device.expanded_name
          sch_ref_name = dev_to_sch_name_map[dev_name] || dev_to_sch_name_map[device.name]
          next unless sch_ref_name

          sub_cat = rdb.create_category(cat_ref, sch_ref_name)
          dev_region = RBA::Region.new

          # 端子（Terminal）形状を取得して合成
          if device.device_class
            device.device_class.terminal_definitions.each do |term_def|
              begin
                t_ref = device.terminal_ref(term_def.id)
                next unless t_ref

                term_shapes = lvs_data.shapes_of_terminal(t_ref)
                if term_shapes.is_a?(Hash)
                  term_shapes.each_value do |reg|
                    dev_region += reg if reg.is_a?(RBA::Region) && !reg.is_empty?
                  end
                elsif term_shapes.is_a?(RBA::Region) && !term_shapes.is_empty?
                  dev_region += term_shapes
                end
              rescue
                # 個別端子の取得エラー時はスキップ
              end
            end
          end

          next if dev_region.is_empty?

          dev_region.each do |poly|
            item = rdb.create_item(rdb_cell, sub_cat)
            item.add_value(poly)
            item_count += 1
          end
        end
      end

      # --- C. 表示とファイル保存 ---
      if item_count > 0
        rdb_path = File.join(Dir.pwd, "lvs_annotation_result.lyrdb")
        rdb.save(rdb_path)

        if view
          rdb_id = view.add_rdb(rdb)
          cv_idx = view.active_cellview_index
          view.show_rdb(rdb_id, cv_idx >= 0 ? cv_idx : 0)
        end
      end
    end

def extract_lvs_data_with_nets(lvsdb) # created by gemini but no longer used
    # 1. lvsdb が保持する Layout と Schematic のネットリストを取得
    netlist = lvsdb.netlist
    layout = lvsdb.internal_layout
    dbu = layout ? layout.dbu : 0.001

    # 2. lvsdb から比較を実行し、確実な CrossReference を生成
    # (lvsdb は RBA::LayoutVsSchematic のため compare が正当な API です)
    cross_ref = nil
    begin
      cross_ref = lvsdb.compare
    rescue => e
      # compare が呼べない、またはすでに完了している場合の安全処理
    end

    net_list = []
    device_data_list = []
    wire_segments = []
    zone_polygons = []

    netlist.each_circuit do |circuit|
      # ネットマップの作成
      net_map = {}
      circuit.each_net do |net|
        net_name = net.expanded_name
        net_name = net.name if net_name.empty?
        net_map[net] = { name: net_name, obj: net }
        net_list << net_name unless net_name.empty?
      end

      # 3. デバイスの抽出とリファレンス名の変換
      circuit.each_device do |device|
        # デフォルト（レイアウト側名: $1, $2 等）
        ref_name = device.expanded_name.empty? ? device.name : device.expanded_name

        # CrossReference が取得できている場合のみ照合
        if cross_ref && cross_ref.respond_to?(:device_pair_for_device)
          begin
            dev_pair = cross_ref.device_pair_for_device(device)
            if dev_pair
              sch_dev = (dev_pair.first == device) ? dev_pair.second : dev_pair.first
              if sch_dev
                sch_name = sch_dev.expanded_name
                sch_name = sch_dev.name if sch_name.empty?
                ref_name = sch_name unless sch_name.empty?
              end
            end
          rescue => e
          end
        end

        device_class = device.device_class.name
        pos_x_mm = device.trans.disp.x * dbu
        pos_y_mm = device.trans.disp.y * dbu

        pins_nets = {}

        # ピン接続情報
        device.device_class.terminal_definitions.each do |term_def|
          term_name = term_def.name
          dev_term = device.net_for_terminal(term_def.id)
          target_name = "NC"

          if dev_term
            net_obj = dev_term.respond_to?(:net) ? dev_term.net : dev_term

            if net_obj && net_obj.is_a?(RBA::Net)
              net_name = net_obj.expanded_name
              net_name = net_obj.name if net_name.empty?

              if !net_name.empty?
                target_name = net_name
              elsif net_map[net_obj]
                target_name = net_map[net_obj][:name]
              else
                c_id = net_obj.cluster_id rescue nil
                matched = net_map.find do |n, info|
                  n == net_obj || (c_id && n.respond_to?(:cluster_id) && n.cluster_id == c_id)
                end
                target_name = matched[1][:name] if matched
              end
            end
          end

          pins_nets[term_name] = target_name
        end

        device_data_list << {
          ref:     ref_name,
          fp_name: device_class,
          x:       pos_x_mm,
          y:       pos_y_mm,
          pins:    pins_nets
        }
      end
    end

    # 4. 返却形式
    {
      nets:     net_list.uniq,
      devices:  device_data_list,
      segments: wire_segments,
      zones:    zone_polygons
    }
  end

  def map_klayout_layer_to_kicad(layer_num)
    case layer_num
    when 1 then "F.Cu"
    when 2 then "B.Cu"
    else "F.Cu"
    end
  end
end

  def self::gds_to_pcb(lvs_data=nil, ml1=nil, ml2=nil)
    include RBA
    include MinedaPCellCommonModule
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
    kc = KiCadGenerator.new layout, pretty_dir, layers, lvs_data, ml1, ml2
  
    Dir.chdir(pretty_dir){
      kc.generate_MX_footprints
    }
    kicad_elements, segments = kc.convert_pcells_to_kicad_mods top_cell

    puts kicad_elements.inspect
    offset_x, offset_y = kc.centerize kicad_elements
    offset_x = 0.0 if offset_x.abs < 30.0
    offset_y = 0.0 if offset_y.abs < 30.0   
    footprints = kc.generate_footprints kicad_elements, offset_x, offset_y, pcell_lib
    segments = kc.convert_paths_and_cells_to_kicad_segments top_cell
    kc.write_pcb footprints, segments, pcb_file
    puts "KiCad PCB successfully generated: #{pcb_file}"
  end
end
