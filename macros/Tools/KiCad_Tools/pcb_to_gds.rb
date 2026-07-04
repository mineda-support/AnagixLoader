# coding: utf-8
  def rot_to_am rotation
    case rotation
    when 'R0'
      [0, false]
    when 'R90'
      [1, false]
    when 'R180'
      [2, false]
    when 'R270'
      [3, false]
    when 'M0'
      [0, true]
    when 'M45'
      [1, true]
    when 'M90'
      [2, true]
    when 'M135'
      [3, true]
    end
  end
  
module PCB_to_gds
  include RBA
  include MinedaPCellCommonModule
  
  mw = Application.instance.main_window
  view = mw.current_view.active_cellview
  if view
    pcb_file = QFileDialog::getOpenFileName(mw, 'KiCad PCB file', File.dirname(view.filename), 'pcb(*.kicad_pcb)')
    layout = view.layout
    top_cell = view.cell
    top_cell.clear
  else
    pcb_file = QFileDialog::getOpenFileName(mw, 'GDS file', ENV['HOME']||ENV['HOMEPATH'], 'pcb(*.kicad_pcb)')
    layout = Layout.new
    layout.dbu = 0.001
    top_cell = layout.create_cell(gds_file)
  end
  puts "*** pcb_file #{pcb_file} to GDS conversion started technology: #{view.technology}"
  mpc = MinedaPCellCommon.new
  mpc.set_technology view.technology
  mpc.set_layer_index
  
  dbu = layout.dbu
  layers = {}
  layers["F.Cu"] = layout.layer(mpc.get_layer_index('ML1', false), 0) #layout.layer(LayerInfo.new(6, 0))
  layers["B.Cu"] = layout.layer(mpc.get_layer_index('ML2', false), 0)
  layers["Via"]  = layout.layer(mpc.get_layer_index('VIA1', false), 0)
  puts layers.inspect
  library = Library.library_by_name("PCells") # OpenRule1um
  raise "Library 'PCells for OpenRule1um' not found" unless library

  require 'sxp'
  kpcb = SXP.read(File.read(pcb_file).encode('UTF-8'))
  kpcb[1..-1].each{|blk|
    if blk[0] == :footprint
      blk[1] =~ /^(\S+):(\S+)\.l(\S+)w(\S+)m(\S+)_(\S+)/
      lib, sym, l, w, m, rot = [$1, $2, $3.to_f, $4.to_f, $5.to_i, $6]
      decl = library.layout.pcell_declaration(sym)
      pcell_id = layout.add_pcell_variant(library, decl.id, { "w" => w, "l" => l, "n" => m})
      at = blk.assoc(:at)
      ref = nil
      blk[4..-1].each{|item|
        if item[0] == :property
          if item[1] == 'Reference'
            ref = item[2]
            break
          end
        end 
      }
      x, y = [at[1], at[2]].map(&:to_f)
      angle, mirror = rot_to_am rot
      puts "#{ref} at [#{(x/dbu).to_i}, #{(-y/dbu).to_i}] #{sym} with #{rot}"
      fp_trans = Trans.new(90*angle, mirror, (x/dbu).to_i, (-y/dbu).to_i)
      top_cell.insert(CellInstArray.new(pcell_id, fp_trans))
    elsif blk[0] == :segment
      start = blk.assoc(:start)[1..2].map(&:to_f) # [:start, 160.3, 94.7)
      end_ = blk.assoc(:end)[1..2].map(&:to_f) 
      width = blk.assoc(:width)[1].to_i
      layer = blk.assoc(:layer)[1]
      puts "Path #{layer}: #{start[0]}, #{start[1]}, #{end_[0]}, #{end_[1]}, #{blk.assoc(:width)[1].to_f}"
      p1 = Point.new((start[0]/dbu).to_i, (-start[1]/dbu).to_i)
      p2 = Point.new((end_[0]/dbu).to_i, (-end_[1]/dbu).to_i)
      path = Path.new([p1, p2], (width/dbu).to_i)     
      top_cell.shapes(layers[layer]).insert(path)
   end
  }
#  output_path = "c:/tmp/ring_oscillator_output.gds"
#  layout.write(output_path)
#  puts "GDS successfully generated: #{output_path}"
  if mw.current_view
    mw.current_view.zoom_fit
  end
end
