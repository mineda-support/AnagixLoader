# coding: utf-8
module PCB_to_gds
  include RBA
  include MinedaCommon
  include MinedaPCellCommonModule
  require 'securerandom'
  
  TARGET_CENTER_X = 150.0  # A4枠(297x210)のほぼ中央
  TARGET_CENTER_Y = 100.0  # A4枠(297x210)のほぼ中央
  SCALE = 1 # 200.0  
  
  def self.centerize placement_data
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
  
  def self.generate_footprints placement_data, offset_x, offset_y, lib_name, pretty_dir
    # フットプリント（footprint）セクションの生成
    footprints_sexpr = ""

    placement_data.each_pair do |ref, item|
      #ref = item[0]        # 素子名 (e.g., M5)
      item.unshift ref
      x = item[1].to_f     # X座標
      y = item[2].to_f     # Y座標
      fp_name = item[3]    # フットプリント名 (e.g., Pch.M0l2.0w6.0m1)

      # KiCadの座標系（通常はmm）。
      # 必要に応じてGDSの単位（μm等）からmmへのスケール変換（例: x * 0.001）をここで行ってください。
      pos_x = ((x * SCALE) + offset_x).round(4)
      pos_y = ((y * SCALE) + offset_y).round(4)

      uuid = SecureRandom.uuid
  
      fp_body = get_footprint_body(fp_name, ref, pretty_dir)

      footprints_sexpr << "  (footprint \"#{lib_name}:#{fp_name}\" (at #{pos_x} #{pos_y}) (layer \"F.Cu\")\n"
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
  def self.get_footprint_body(fp_name, ref, pretty_dir)
    mod_path = File.join(pretty_dir, "#{fp_name}.kicad_mod")
    return "" unless File.exist?(mod_path)

    lines = File.read(mod_path)
    lines.sub!(/fp_text reference \"\S+\"/, "fp_text reference \"#{ref}\"")
    # 最初の行 (footprint ...) と最後の行 ) を除いた、中身の行だけを結合する
    body_lines = lines.split("\n")[1...-1]
    body_lines ? body_lines.join("\n"): ""
  end

  def self.write_pcb footprints, segments, pcb_file
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
  dbu = layout.dbu
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

  kicad_elements = {}
  count = 0
  top_cell.each_inst{|inst|
    puts "#{inst.cell.name}(#{inst.property('name')}): #{inst.trans.to_s}"
    next unless inst.is_pcell?
    l=inst.pcell_parameter 'l'
    w=inst.pcell_parameter 'w'
    m=inst.pcell_parameter 'n'
    rot = inst.trans.to_s.sub(/ .*$/, '').upcase
    kicad_cell_name = "#{inst.cell.name.sub(/\$.*$/,'')}.l#{l}w#{w}m#{m}"
    infile = File.join(pretty_dir, kicad_cell_name + '.kicad_mod')
    if File.exist?(infile)
      count = count + 1
      name = inst.property('name') || inst.cell.name.sub(/\$.*$/,'')+count.to_s
      content = File.read(infile, encoding: 'utf-8')
      transformer = KiCadModTransformer.new(rot)
      kicad_cell_rot = kicad_cell_name + '_' + rot
      result = transformer.transform(content, kicad_cell_rot, name)
      File.write(File.join(pretty_dir, kicad_cell_rot) + '.kicad_mod', result, encoding: 'utf-8')
      kicad_elements[name] = [(inst.trans.disp.x*layout.dbu).round(4), (-inst.trans.disp.y*layout.dbu).round(4), kicad_cell_rot]
    else
      puts "#{infile} does not exist!"
    end
  }
  puts kicad_elements.inspect
  offset_x, offset_y = centerize kicad_elements
  footprints = generate_footprints kicad_elements, offset_x, offset_y, pretty_lib, pretty_dir
  
  segments = ''
  layers.each_pair do |name, layer|
    top_cell.shapes(layer).each{|shape|
      next unless shape.is_path?
      op = nil
      shape.each_point{|p|
        unless op.nil?
          segments << <<EOF
	(segment
		(start #{op.x/1000.0+offset_x} #{-op.y/1000.0+offset_y})
		(end #{p.x/1000.0+offset_x} #{-p.y/1000.0+offset_y})
		(width #{shape.path_width/1000.0})
		(layer #{name})
		
		(uuid SecureRandom.uuid)
	)
EOF
        end
        op = p
      }
    }
  end
  write_pcb footprints, segments, pcb_file
  puts "KiCad PCB successfully generated: #{pcb_file}"
end
