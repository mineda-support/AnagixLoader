# Mineda Common
#   Force on-grid v0.1 July 39th 2022 copy right S. Moriyama (Anagix Corp.)
#   LVS preprocessor(get_reference) v0.68 Jan. 2nd 2023 copyright by S. Moriyama (Anagix Corporation)
#   * ConvertPCells and PCellDefaults moved from MinedaPCell v0.4 Nov. 22nd 2022
#   ConvertPCells v0.1 Dec. 26th 2022  copy right S. Moriyama
#   PCellTest v0.2 August 22nd 2022 S. Moriyama
#   DRC_helper::find_cells_to_exclude v0.1 Sep 23rd 2022 S. Moriyama
#   MinedaInput v0.32 Jan. 5th 2023 S. Moriyama
#   MinedaPCellCommon v0.2 Dec. 8th 2022 S. Moriyama
#   Create Backannotation data v0.15 Dec. 12th 2022 S. Moriyama

module MinedaPCellCommonModule
  include RBA
  class MinedaPCellCommon < PCellDeclarationHelper
    include RBA
    attr_accessor :defaults, :layer_index
    @@lyp_file = @@basic_library = @@layer_index = nil
    def initialize
      key = 'PCells_' + self.class.name.to_s.split('::').first + '-defaults'
      @defaults = YAML.load(Application.instance.get_config key)
      # puts "Got PCell @defaults from #{key}"
      set_layer_index
      super
    end

    def set_technology tech_name
      tech = RBA::Technology::technology_by_name(tech_name)
      @@lyp_file = File.join(tech.base_path, tech.layer_properties_file)
      @@layer_index = self.class.get_layer_index_from_file @@lyp_file
    end

    def set_basic_library basic_lib
      @@basic_library = basic_lib
    end

    def self.get_layer_index_from_file lyp_file
      return unless lyp_file
      require 'rexml/document'
      doc = REXML::Document.new(File.open(lyp_file))
      layer_index = {}
      doc.elements.each('layer-properties/properties'){|e|
        name = e.get_text('name').to_s.sub(/\(.*$/, '')
        valid = e.get_text('valid')
        next if valid == 'false'
        e.get_text('source').to_s =~ /([0-9]+)\/([0-9]+)/
        index = $1.to_i
        data_type = $2.to_i
        layer_index[name] = [index, data_type]
      }
      # puts layer_index
      layer_index
    end

    def set_layer_index
      @basic_library = @@basic_library
      @layer_index = @@layer_index
    end

    def get_layer_index name
      layer, data_type = @layer_index[name]
      # puts "get_layer_index:for #{name} = #{layer}/#{data_type}"
      layout.insert_layer(LayerInfo::new layer, data_type)
    end

    def get_cell_index name
      library_cell name, @basic_library, layout
    end

    def param name, type, desc, last_resort
      cellname = self.class.name.to_s.split('::').last.to_s
      if @defaults && @defaults[cellname]
        if (value = @defaults[cellname][name.to_s]) || (value == nil) || (value == false)
          # puts "#{self.class.name} '#{name}' => #{value}"
          if last_resort[:default] == true
            super name, type, desc, {default: value}
          else
            super name, type, desc, value ? {default: value} : last_resort
          end
        elsif value = @defaults[cellname][name.to_s + '_hidden']
          # puts "#{self.class.name} '#{name}' => #{value} 'hidden' => true"
          super name, type, desc, value ? {default: value, hidden: true} : last_resort
        else
          super name, type, desc, value ? {default: value} : last_resort
        end
      else
        super name, type, desc, last_resort
      end
    end

    def library_cell name, libname, layout
      if cell = layout.cell(name)
        return cell.cell_index
      else
        lib = Library::library_by_name libname
        if lib && cell = lib.layout.cell(name)
          proxy_index = layout.add_lib_cell(lib, cell.cell_index)
        end
      end
    end

    def create_box index, x1, y1, x2, y2
       cell.shapes(index).insert(Box::new(x1, y1, x2, y2)) if  index
    end

    def insert_cell via_index, x, y, rotate=false
      via = CellInstArray.new(via_index, rotate ? Trans.new(1, false, x, y) : Trans.new(x, y))
      inst = cell.insert(via)
    end

    def create_path index, x1, y1, x2, y2, w, be, ee
      points = [Point::new(x1, y1), Point::new(x2, y2)]
      cell.shapes(index).insert(Path::new(points, w, be, ee))
    end

    def create_path2 index, x1, y1, x2, y2, x3, y3, w, be, ee
      points = [Point::new(x1, y1), Point::new(x2, y2), Point::new(x3, y3)]
      cell.shapes(index).insert(Path::new(points, w, be, ee))
    end

    def create_dcont index, x1, y1, x2, y2, vs, dcont_offset=nil
      dcont_offset ||= 0
      if dcont_offset != 0
        dcont_offset = 0 if dcont_offset == true
        n = (y2 - y1 - 2*dcont_offset)/vs
        dcont_offset = (y2 - y1 - n*vs)/2
      end
      # puts [y1+vs/2 + dcont_offset, y2-vs/2 - dcont_offset, vs].inspect
      (y1+vs/2 + dcont_offset .. y2-vs/2 - dcont_offset).step(vs){|y|
        # puts "insert #{index}@#{x1},#{y}"
        insert_cell index, x1, y
      }
    end

    def overcoat layer, original
      cell.shapes(original).each{|shape|
        if shape.is_path?
          path = shape.path
          cell.shapes(layer).insert(Path::new path)
        elsif shape.is_box?
          box = shape.box
          cell.shapes(layer).insert(Box::new box)
        elsif shape.is_polygon?
          polygon = shape.polygon
          cell.shapes(layer).insert(Polygon::new polygon)
        end
      }
    end
         
    def boxes_bbox original
      return nil unless original
      xmin = ymin = 10000000
      xmax = ymax = -xmin
      cell.shapes(original).each{|shape|
        box = shape.bbox
        x1, y1, x2, y2 = [box.p1.x, box.p1.y, box.p2.x, box.p2.y]
        puts "[x1, y1, x2, y2]=#{[x1, y1, x2, y2].inspect}"
        xmin = [xmin, x1].min
        ymin = [ymin, y1].min
        xmax = [xmax, x2].max
        ymax = [ymax, y2].max
      }
      [xmin, ymin, xmax, ymax] unless xmin == 10000000
    end
    
    def cell_bbox index
      result = nil
      cell.each_inst{|inst|
        if inst.cell_index == index
          result = [inst.bbox.p1.x, inst.bbox.p1.y, inst.bbox.p2.x, inst.bbox.p2.y]
          break
        end
      }
      result
    end
  
    def fill_area area, square_size, layer_index=nil
      x1, y1, x2, y2, margin = area
      margin_x = margin_y = (margin || 0)
      if margin.class == Array
        margin_x, margin_y = margin
      end
      create_box layer_index, x1, y1, x2, y2 if layer_index
      n = ((x2 - x1 - 2*margin_x)/square_size).to_i
      xoffset = x2 - x1 - n * square_size
      m = ((y2 - y1 - 2*margin_y)/square_size).to_i
      yoffset = y2 - y1 - m * square_size
      for i in 0..[n-1, 0].max
        for j in 0..[m-1, 0].max
          yield x1 + xoffset/2 + (n<=0? 0 : i*square_size + square_size/2), y1 + yoffset/2 +  (m<=0? 0 : j*square_size + square_size/2)
        end
      end
    end
    
    def create_loop index, xs, ys, xl, yl, w
      points = [Point::new(xs, ys), 
                Point::new(xs, ys - yl), 
                Point::new(xs - xl, ys - yl),
                Point::new(xs - xl, ys),
                Point::new(xs, ys)]
      cell.shapes(index).insert(Path::new(points, w, w/2, -w/2).simple_polygon)           
    end
    
    def enlarge_area area, delta_x, delta_y
      new_area = area
      new_area[0] = new_area[0] - delta_x
      new_area[1] = new_area[1] - delta_y
      new_area[2] = new_area[2] + delta_x
      new_area[3] = new_area[3] + delta_y
      new_area
    end      
  end
end

module MinedaCommon
  class DRC_helper
    def find_cells_to_exclude layer, pattern, skin_thickness=0
      @pattern = pattern
      @cv = MinedaCommon::ConvertPCells::current_cellview()
      @st = skin_thickness/@cv.layout.dbu
      @layer= @cv.layout.layer(RBA::LayerInfo::new(*layer))
      @cv.cell.shapes(@layer).each{|s| s.delete}
      puts "All the shapes in layer: #{layer} deleted"
      @cv.cell.each_inst{|inst|
        find_cells_recursive inst, @cv.context_trans
      }
    end
#    def go
#      find_cells_to_exclude  [63, 63], '^a[np]5g', 5.0
#    end
    def find_cells_recursive inst, trans
      cell = inst.cell
      if cell.child_instances > 0
        inst.cell_inst.each_cplx_trans{|a|
          cell.each_inst do |inst2|
            trans2 = trans * a
            find_cells_recursive(inst2, trans2)
          end
        }
      elsif cell.name =~ /#{@pattern}/
        box = inst.bbox
        p1 = box.p1
        p2 = box.p2
        box = RBA::Box::new(p1.x + @st, p1.y + @st, p2.x - @st, p2.y - @st)
        @cv. cell.shapes(@layer).insert(box.transformed trans)
        puts "#{inst_cell_name} @ #{inst.bbox}, #{trans}"
      end
    end
  end
  
  class MinedaInput
    include RBA
    attr_accessor :layer_index
    def initialize source, params={}
      @source = source
      tech = @source.layout.technology
      lyp_file = File.join(tech.base_path, tech.layer_properties_file)
      @layer_index = MinedaPCell::MinedaPCellCommon::get_layer_index_from_file lyp_file
    end

    def index layer_name
      @layer_index[layer_name]
    end
    
    def get_reference
      sdir = File.dirname @source.path
      ext_name = File.extname @source.path
      @target = File.basename(@source.path).sub(ext_name, '')
      output = File.join sdir, "#{@target}_output.cir"
      @lvs_work = File.join(sdir, 'lvs_work')
      reference = File.join(@lvs_work, "#{@target}_reference.cir.txt")
      Dir.mkdir @lvs_work unless File.directory? @lvs_work
      if File.exist? File.join(sdir, @target+'.yaml')
        require 'yaml'
        ref = YAML.load File.read(File.join sdir, @target+'.yaml')
        if File.exist? ref['netlist']
          if File.exist?(ref['schematic']) && (File.mtime(ref['netlist']) < File.mtime(ref['schematic']))
            raise "netlist file '#{ref['netlist']}' is outdated!\nPlease update netlist and run get_reference again!"
          end
          if File.exist?(reference) && (File.mtime(reference) < File.mtime(ref['netlist']))
            raise "Please run get_reference because netlist file '#{ref['netlist']}'is modified"
          end
        end
      end
      [reference, output]
    end
    
    def get_settings
      puts "settings file: #{@lvs_work}/#{@target}_lvs_settings.rb"
      if File.exist? "#{@lvs_work}/#{@target}_lvs_settings.rb"
        "#{@lvs_work}/#{@target}_lvs_settings.rb"
      end
    end
    
    def start exclude
      reference, output = get_reference
      if settings = get_settings
        load settings
        if defined? set_blank_layout
          exclude = set_blank_layout
        end
      end
      [reference, output, settings]
    end
    
    def lvs reference, output, lvs_data, l2n_data, is_deep = false
      if File.exist? reference
        yield
        create_ba_data lvs_data
        make_symlink output
      else
        create_ba_table l2n_data, is_deep
      end
    end
    
    def make_symlink output
      # Netlist vs. netlist
      slink = "#{@lvs_work}/#{File.basename output}.txt"
      File.delete slink if File.exist?(slink) || File.symlink?(slink)
      if /mswin32|mingw/ =~ RUBY_PLATFORM
        File.link output, slink
      else
        File.symlink "../#{File.basename output}", slink
      end
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
    
    def create_ba_table l2n_data, is_deep
      unless is_deep
        puts "Caution: backannotation table (xxx.table.yaml) will be created only when LVS mode is deep"
        return
      end
      ext_name = File.extname @source.path
      target = File.basename(@source.path).sub(ext_name, '') 
      # trans_data = []
      ba_data = {}
      l2n_data.netlist.each_circuit{|c|
        puts c.name
        rest = []
        devices_count = 0
        c.each_device{|device| devices_count = devices_count + 1}
        count = 0
        c.each_device{|device|
          puts [device.expanded_name, device.device_class.name, device.device_abstract.name, device.trans.to_s].inspect
          # trans_data << device.trans
          prefix = find_prefix(device.device_class.class.name)
          case prefix
          when 'M' 
            l = device.parameter('L').round(4)
            w = device.parameter('W').round(4)
            displacement = device.trans.disp
            rest << [[displacement.x.round(6), displacement.y.round(6)]]+ # , device.trans.to_s
                   [['AS', 'AD', 'PS', 'PD'].map{|p| device.parameter(p).round(6)}]
            dcname = device.device_class.name
            ba_data[prefix] ||= {}
            ba_data[prefix][dcname] ||= {}
            ba_data[prefix][dcname][l] ||= {}
            count = count + 1
            if count == devices_count
              w_key = "#{w}*#{rest.size}"
              ba_data[prefix][dcname][l][w_key] ||= {}
              ba_data[prefix][dcname][l][w_key] = rest
            end
          end
       }
      }
      # puts ba_data.inspect
      Dir.chdir(File.dirname @source.path){
        table_file = target + '_table.yaml'
        File.open(table_file, 'w'){|f|
          f.puts ba_data.to_yaml
        }
        puts "#{table_file} created under #{Dir.pwd}"
      }
      # trans_data
    end
      
    def create_ba_data lvs_data
      ext_name = File.extname @source.path
      target = File.basename(@source.path).sub(ext_name, '') 
      Dir.chdir(File.dirname @source.path){
        if File.exist? file = target + '_ba.yaml'
          File.delete(file)
        end
      }      
      ba_data = {}
      status = nil
      lvs_data.xref.each_circuit_pair.each{|c|
        puts "LVS result for #{c.second.name}: #{c.status}"
        next unless c.status == NetlistCrossReference::Match ||
                    c.status == NetlistCrossReference::MatchWithWarning
        status = c.status
        cname = c.second.name
        ba_data[cname] = {}
        lvs_data.xref.each_device_pair(c).each{|device| 
          next unless ext = device.first
          if ref = device.second
            unless prefix = find_prefix(ext.device_class.class.name)
              puts "#{ref.device_class.class} does not match"
              prefix = ''
            end
            dname = ref.expanded_name
            if dname =~ /^\d+$/
              device = prefix + dname
              ba_data[cname][device] ||= {}
              ext && ext.device_class.parameter_definitions.each{|p|
                ba_data[cname][device][p.name] = ext.parameter(p.name)
              }
            elsif dname =~ /^(.*)\.(\d+)$/
              ckt = $1
              device = prefix + $2
              ba_data[cname][ckt] ||= {}
              ba_data[cname][ckt][device] ||= {}
              ext && ext.device_class.parameter_definitions.each{|p|
                ba_data[cname][ckt][device][p.name] = ext.parameter(p.name)
              }
            end
          end
        }
      }
      status && Dir.chdir(File.dirname @source.path){
        File.open(target + '_ba.yaml', 'w'){|f|
          f.puts ba_data.to_yaml
        }
      }
      status
    end
  end

  class PCellTest
    include RBA  
    def initialize
      cv = ConvertPCells::current_cellview
      @cell = cv.cell
      @lib = Library::library_by_name 'PCells_' + cv.technology
      @xpos = @ypos = 0
      # @defaults = PCellDefaults::get_defaults @lib.name
      puts cv
    end
    def create_pcell name, params
      pd = @lib.layout.pcell_declaration(name)
      raise "No pcell declartion for #{name}" if pd.nil?
      puts "params for #{name}: #{params.inspect}"
      # @defaults[name].each_pair{|p, v|
      #   params[p] ||= v
      # }
      puts "=> #{params.inspect}"
      @cell.layout.add_pcell_variant(@lib, pd.id, params)
    end
    def insert_pcell x, y, name, params
      pcv = create_pcell name, params
      inst=@cell.insert RBA::CellInstArray::new(pcv, Trans::new(x,y))
      puts "=> #{inst.pcell_parameters_by_name}"
    end
    def get_defaults pcell_lib = @lib.name
      params = YAML.load(PCellDefaults::dump_pcells pcell_lib)
      defaults = {}
      params.keys.each{|key|
        defaults[key.to_s] = params[key]
      }
      defaults
    end
    def render_pcells(pcvs, width, height, ncolumns)
      w = (width/@cell.layout.dbu).to_i
      h = (height/@cell.layout.dbu).to_i
      count = 0
      pcvs.each{|pcv|
        @xpos = @xpos + w
        count = count + 1
        inst = @cell.insert RBA::CellInstArray::new(pcv, Trans::new(@xpos, @ypos))
        # puts "=> #{inst.pcell_parameters_by_name}"
        if (count % ncolumns) == 0
          count = 0
          @xpos = 0
          @ypos = @ypos + h
        end
      }
      @xpos = 0
      @ypos = @ypos + h
    end
    
    def do_sweep new_sweep, params = {}, &block
      sweep = new_sweep.dup
      #puts "sweep=#{sweep}, params = #{params}"
      if sweep && sweep.size > 0
        new_sweep = sweep.delete('sweep')
        longest = nil
        sweep.each_key{|k|
          longest = k if longest.nil? || sweep[k].length > sweep[longest].length
        }
        prev = {}
        for i in 0..(sweep[longest].length - 1) do
          sweep.each_pair{|k, v|
            params[k] = v[i].nil? ? prev[k] : v[i]
            prev[k] = params[k]
          }
          do_sweep new_sweep, params, &block
        end
      else
        yield params
        # puts "###{params.inspect}"
      end
    end
    def create_samples device, width, height, ncolumns, sweep_spec
      pcvs = []
      do_sweep(YAML.load(sweep_spec)['sweep']){|params|
        pcvs << create_pcell(device, params)
      }
      render_pcells(pcvs, width, height, ncolumns)
    end
  end

  class ConvertPCells
    def initialize pcell_module
      @technology_name = pcell_module.sub(/_v[^_]*$/, '')
      @pcell_lib = ('PCells_' + @technology_name).sub('PCells_OpenRule1um', 'PCells')
      @basic_lib = @technology_name + '_Basic'
      @defaults = PCellDefaults::get_defaults @pcell_lib
      @pcell_module = pcell_module
    end
    def convert_library_cells cv, pcell_lib, basic_lib, pcell_factor=1.0
      # puts "@defaults=#{@defaults}"
      convert_library_cells0 cv.cell, pcell_lib, basic_lib, pcell_factor
    end
    def convert_library_cells0 cell, pcell_lib, basic_lib, pcell_factor
      lib = RBA::Library::library_by_name pcell_lib
      bas_lib = RBA::Library::library_by_name basic_lib
      cells_to_delete = []
      cell.each_inst{|inst|
        t = inst.trans
        inst_cell_name = (@device_mapping && @device_mapping[inst.cell.name]) || inst.cell.name          
        puts inst.cell.name
        inst_cell_name.sub! /\$.*$/, ''
        if inst.cell.is_pcell_variant?
          next if inst.cell.library == lib # already converted
          pcell_params = inst.pcell_parameters_by_name
          if pcell_factor
            pcell_params['l'] = pcell_params['l']*pcell_factor
            pcell_params['w'] = pcell_params['w']*pcell_factor
            if @defaults[inst_cell_name] 
              if @defaults[inst_cell_name]['sdg'].nil?
                pcell_params['sdg'] = pcell_params['sdg']*pcell_factor if pcell_params['sdg'] 
              else
                pcell_params['sdg'] = @defaults[inst_cell_name]['sdg']
              end
            end
          end
          @defaults[inst_cell_name] && @defaults[inst_cell_name].each_pair{|p, v|
            name = p.sub '_hidden', ''
            pcell_params[name] || pcell_params[name] = v 
          }
          puts "pcell parameters for #{inst.trans}(#{inst_cell_name}): #{pcell_params.inspect}"
          next unless pd = lib.layout.pcell_declaration(inst_cell_name) 
          pcv = cell.layout.add_pcell_variant(lib, pd.id, pcell_params)
          pcell_inst = cell.insert(RBA::CellInstArray::new(pcv, t))
        elsif inst.cell.library && inst.cell.library.name =~ /_Basic/
          next if inst.cell.library == bas_lib # already converted
          basic_cell = bas_lib.layout.cell(inst_cell_name)
          raise "basic_cell for #{inst_cell_name} not found" if basic_cell.nil?
          proxy_index = cell.layout.add_lib_cell(bas_lib, basic_cell.cell_index)
          basic_inst = cell.insert(RBA::CellInstArray.new(proxy_index, t))       
        else
          next
        end
        cells_to_delete << inst.cell
        #inst.cell.each_child_cell{|id|
        #  cells_to_delete << cell.layout.cell(id)
        #}
        inst.delete
      }
      if false && cells_to_delete.size > 0
        puts "### CELLS TO DELETE: #{cells_to_delete.map{|c| [c.name, c.library.name]}.uniq.inspect}"
        cells_to_delete.uniq.each{|c|
         # puts "#{c.name}@#{c.library.name}"
         c.delete
        }
      end
      child_cells = []
      cell.each_child_cell{|id| child_cells << id}
      child_cells.each{|id|
        c = cell.layout.cell(id)
        if c.child_instances > 0
          puts c.name
          convert_library_cells0 c, pcell_lib, basic_lib, pcell_factor
        end
      }
    end
    include RBA
    def do_convert_library_cells args
      app = Application.instance
      mw = app.main_window
      @cv = mw.current_view.active_cellview
      file = args[:target] || QFileDialog::getSaveFileName(mw, 'Converted File name', File.dirname(@cv.filename))
      file = file + '.GDS' unless File.extname(file).upcase == '.GDS'
      opt = SaveLayoutOptions.new
      opt.scale_factor = args[:routing_scale_factor] || 1
      @cv.cell.write file, opt
      technology_name = @cv.technology
      puts "Current technology: #{technology_name}"
      @technology_name = args[:technology_name] || @technology_name
      opt = LoadLayoutOptions.new
      if map_file = args[:layer_map] && File.exist?(map_file)
        opt.layer_map = LayerMap::from_string File.read(map_file) 
      else
        opt.layer_map = LayerMap::from_string self.class.create_map(@cv, @pcell_module, @technology_name)
      end
      opt.create_other_layers = false # layers not listed in this layer map are ignored (not created)
      cv = mw.load_layout file, opt, technology_name, 1 #  mode 1 means new view
      @pcell_lib = args[:pcell_lib] || @pcell_lib
      @basic_lib = args[:basic_lib] || @basic_lib
      @device_mapping = args[:device_mapping]
      convert_library_cells cv, @pcell_lib, @basic_lib, args[:pcell_scale_factor]
      cv.technology = @technology_name
      # cv.cell.write file
      Dir.chdir(File.dirname(@cv.filename)){
        org_cir = File.join 'lvs_work', File.basename(@cv.filename).sub(/\.(gds|GDS)/, '_reference.cir.txt')
        puts "org_cir: #{org_cir}"
        if File.exist?(org_cir)
          tgt_dir = File.join File.dirname(file), 'lvs_work'
          FileUtils.mkdir tgt_dir unless File.directory? tgt_dir
          tgt_cir = File.join tgt_dir, File.basename(file).sub(/\.(gds|GDS)/, '_scaled.net')
          convert_circuit org_cir, tgt_cir, args[:pcell_scale_factor]
        end
      }
    end
    
    def convert_circuit org_cir, tgt_cir, factor
      f = File.open(tgt_cir, 'w')
      File.read(org_cir).encode('UTF-8', invalid: :replace).each_line{|line|
        if line =~ /^M.* +(L=(.*)[UN]) +(W=(.*)[UN])/
          l = $2
          w = $4
          l_desc = $1
          w_desc = $3
          new_l = l_desc.sub(l, (l.to_f*factor).round(4).to_s)
          new_w = w_desc.sub(w, (w.to_f*factor).round(4).to_s)
          line = line.sub(w_desc, new_w).sub(l_desc, new_l)
        end
        f.puts line
      }
      f.close
    end
  
    def self.create_map cv, pcell_module, technology_name = pcell_module.sub(/_v[^_]*$/, '')
      # mpc = pcell_module.send MinedaPCellCommon::new
      mpc = eval "#{pcell_module}::MinedaPCellCommon::new"
      name = technology_name
      unless RBA::Technology.technology_names.include? name
        raise "#{name} is not a valid technology name ... check RBA:Technology.technology_names!"
      end
      mpc.set_technology name # ('PCells_' + name).sub('PCells_OpenRule1um', 'PCells') #.sub('Sky130a', 'SKY130')
      puts "target technology: #{name}:#{mpc.set_layer_index}"
      map = ''
      cv.view.each_layer{|l|
        next unless l.valid?
        layer_name = l.name.sub(/\(.*$/, '')
        if pair = mpc.layer_index[l.name]
          target_layer, target_datatype = pair
          map << "#{l.source_layer}/#{l.source_datatype}:#{target_layer}/#{target_datatype}\n"
        end
      }
      puts map
      map
    end
    
    def self.current_cellview
      app = RBA::Application.instance
      mw = app.main_window
      lv = mw.current_view
      if lv == nil
         raise "No view selected"
      end
      cv = lv.active_cellview
      if !cv.is_valid?
        raise "No cell or no layout found"
      end
      cv
    end
  end
  
  class PCellDefaults
    include RBA

    def self.dump_pcells lib_name, file = nil
      lib = RBA::Library::library_by_name lib_name
      defaults = {}
      if lib.nil?
        #raise 'error' 
        puts "error caused by #{lib_name}"
      end
      lib.layout.pcell_names.each{|name|
        defaults[name] = {}
        lib.layout.pcell_declaration(name).get_parameters.each{|p|
          defaults[name][p.hidden ? p.name + '_hidden' : p.name] = p.default
        }
      }
      File.open(file, 'w'){|f| f.puts defaults.to_yaml} if file
      defaults.to_yaml
    end
    
    def self.get_defaults pcell_lib
      params = YAML.load(PCellDefaults::dump_pcells pcell_lib)
      defaults = {}
      params.keys.each{|key|
        defaults[key.to_s] = params[key]
      }
      defaults
    end
    
    def change_pcell_defaults
      app = RBA::Application.instance
      mw = app.main_window
      cv = mw.current_view.active_cellview
      dialog = QDialog.new(Application.instance.main_window)
      dialog.windowTitle = "Change PCell defaults for #{cv.technology}"
      mainLayout = QVBoxLayout::new(dialog)
      dialog.setLayout(mainLayout)
      tech_map = {'OpenRule1um' => 'PCells', 'OR_TIASCR' => 'PCells_Tiascr130'}
      pcell_map = {'OpenRule1um' => 'OpenRule1um_v2::OpenRule1um', 'OR_TIASCR' => 'Tiascr130::Tiascr130',
                   'Sky130a' => 'Sky130a_v0p2::Sky130a' } # rest are : #{cv.technology}::#{cv.technology}
      lib_name = (tech_map[cv.technology] || 'PCells_' + cv.technology ) 
      key = lib_name + '-defaults'
      config = Application.instance.get_config(key)
      if config.nil? || config == ''
        config = self.class.dump_pcells(lib_name)
      end
      # puts "config for '#{key}': \n#{config}"
      editor = QPlainTextEdit.new(dialog)
      editor.insertPlainText config || ''
      mainLayout.addWidget(editor)
      
      # button boxes
      layout = QHBoxLayout.new(dialog)
      mainLayout.addLayout(layout)
      
      # Save button
      buttonSave = QPushButton.new(dialog)
      layout.addWidget(buttonSave)
      buttonSave.text = ' Save '
      buttonSave.clicked do
        settings_file = QFileDialog::getSaveFileName(mw, 'Save File', File.dirname(cv.filename))
        File.open(settings_file, 'w'){|f| f.puts editor.document.toPlainText}
        puts "#{settings_file} saved"
      end
      
      # Load button
      buttonLoad = QPushButton.new(dialog)
      layout.addWidget(buttonLoad)
      buttonLoad.text = ' Load '
      buttonLoad.clicked do
        file = QFileDialog::getOpenFileName(mw, 'Load File', File.dirname(cv.filename))
        editor.setPlainText File.read(file)
      end

      # OK button
      buttonOK = QPushButton.new(dialog)
      layout.addWidget(buttonOK)
      buttonOK.text = " OK "
      buttonOK.clicked do 
         dialog.accept()
         config = editor.document.toPlainText
         # puts config
         Application.instance.set_config key, config
         puts "PCell defaults set for '#{key}'"
         eval(pcell_map[cv.technology] || "#{cv.technology}::#{cv.technology}").send 'new'
         # puts pcell_map[cv.technology] || "#{cv.technology}::#{cv.technology}"
      end
      # Cancel button
      cancel = QPushButton.new(dialog)
      layout.addWidget(cancel)
      cancel.text = "cancel"
      cancel.clicked do 
        dialog.accept()
      end
      dialog.exec
    end
  end
end

class MinedaGridCheck
  include RBA
  def initialize grid = nil
    @grid = grid 
  end
    
  def fix_offgrid(shape, old_x, old_y)
    p = fixed_point old_x, old_y
    shape.transform Trans.new(Trans::R0, p.x-old_x, p.y-old_y) if p
  end

  def fixed_point old_x, old_y
    x = (old_x/@grid_db).to_i * @grid_db
    y = (old_y/@grid_db).to_i * @grid_db
    unless x == old_x && y == old_y
      puts "(#{old_x}, #{old_y}) => (#{x}, #{y})"
      return Point::new(x, y)
    end
    nil
  end

  def fix_path_points shape
    spine = []
    flag = false
    shape.each_point{|p|
      if new_p = fixed_point(p.x, p.y)
        flag = true
        spine << new_p
      else
        spine << p
      end
    }
    flag && spine
  end
  
  def current_cellview
    app = RBA::Application.instance
    mw = app.main_window
    lv = mw.current_view
    if lv == nil
       raise "No view selected"
    end
    cv = lv.active_cellview
    if !cv.is_valid?
      raise "No cell or no layout found"
    end
    layout = cv.layout
    @grid ||= app.get_config('grid-micron').to_f
    @grid_db = (@grid/layout.dbu.round(3)).to_i
    puts "grid_db = #{@grid_db}"
    [cv, lv]
  end

  def check_off_grid cell, lv
    return if cell.is_library_cell
    puts "*** check offgrid for '#{cell.name}"
    lv.each_layer{|layer_props|
      paths = 0
      cell.shapes(layer_props.layer_index).each{|shape|
         # fix_offgrid(shape, shape.bbox.left, shape.bbox.top)
         if shape.is_path?
           path = shape.path
           if spine = fix_path_points(shape)
             path.points= spine
             shape.path = path
           end
           paths = paths + 1
         elsif shape.is_box?
           box = shape.box
           flag = false
           if p = fixed_point(box.left, box.top)
             box.top = p.y
             box.left = p.x
             flag = true
           end
           if p = fixed_point(box.right, box.bottom)
             box.bottom = p.y
             box.right = p.x
             flag = true
           end
           shape.box = box if flag
         elsif shape.is_polygon?
           plgn =shape.polygon
           hull = []
           plgn.each_point_hull{|p|
             hull << (fixed_point(p.x, p.y) || p)
           }
           plgn.hull = hull
           plgn.holes.times{|i|
             hole = []
             plgn.each_point_hole(i){|p|
              hole << (fixed_point(p.x, p.y) || p)
              }
             plgn.hole = hole
           }
           shape.polygon = plgn
         end
      }
      puts "paths=#{paths} for layer:#{layer_props.name}" if paths>0
    }

    cell.each_inst{|inst|
      old_x=inst.trans.disp.x
      old_y=inst.trans.disp.y
      fix_offgrid(inst, old_x, old_y)
    }
          
    child_cells = []
    cell.each_child_cell{|id| child_cells << id}
    child_cells.each{|id|
      c = cell.layout.cell(id)
      #puts c.name
      check_off_grid c, lv
    }
  end
  
  def do_check
    cv, lv = current_cellview()
    check_off_grid cv.cell, lv
  end
end

class MinedaLVS
  include RBA # unless $0 == __FILE__
  require 'fileutils'
  require 'yaml'
  def get_params netlist
    p = {}
    File.open(netlist, 'r:Windows-1252').read.encode('UTF-8', invalid: :replace).each_line{|l|
      l.gsub! 00.chr, ''
      if l.upcase =~/\.PARAM\S* (\S+.*$)/
        params = $1
        params.split.each{|equation|
          equation =~ /(\S+) *= *(\S+)/
          p[$1] = $2
        }
      end
    }
    p
  end

  def expand_file file, lines
    # File.open(file, 'r:Windows-1252').read.encode('UTF-8', invalid: :replace).each_line{|l|
    File.open(file, 'r:Windows-1252').read.encode('UTF-8').gsub(181.chr(Encoding::UTF_8), 'u').each_line{|l|
      if l.chop =~ /.inc\S* +(\S+)/
        include_file = $1
        lines << '*' + l
        if File.exist? include_file
          lines = expand_file(include_file, lines)
        end
      else
        lines << l
      end
    }
    # puts "*** #{file}:"
    # puts lines
    lines
  end

  def lvs_go target_technology, settings = {}
    app = Application.instance
    mw = app.main_window
    cv = mw.current_view.active_cellview
    raise "You are running #{target_technology} version of 'get_reference' against #{cv.technology} layout" unless cv.technology == target_technology
    raise 'Please save the layout first' if cv.nil? || cv.filename.nil? || cv.filename == ''
    cell = cv.cell
    netlist = QFileDialog::getOpenFileName(mw, 'Netlist file', File.dirname(cv.filename), 'netlist(*.net *.cir *.spc *.spice)')
    if netlist && netlist.strip != ''
      netlist = netlist.force_encoding('UTF-8')
      # netlist = '/home/seijirom/Dropbox/work/LRmasterSlice/comparator/COMP_NLF.net'
      # raise "#{netlist} does not exist!" unless File.exist? netlist
      Dir.chdir File.dirname(cv.filename).force_encoding('UTF-8')
      ext_name = File.extname cv.filename
      target = File.basename(cv.filename).sub(ext_name, '')
      Dir.mkdir 'lvs_work' unless File.directory? 'lvs_work'
      reference = File.join('lvs_work', "#{target}_reference.cir.txt")
      ref={'target' => target, 'reference'=> reference, 'netlist'=> netlist, 'schematic' => netlist.sub('.net', '.asc')}
      File.open(target+'.yaml', 'w'){|f| f.puts ref.to_yaml}
      desc = ''
      cells = []
      circuit_top = nil
      device_class = {}
      lines = expand_file netlist, ''
      params = get_params netlist
      puts "params: #{params.inspect}"
      c = File.open(File.join('lvs_work', File.basename(netlist))+'.txt', 'w:UTF-8')
      prev_line = ''
      comment_subckt = inside_subckt = false
      subckt_params = []
      lines.each_line{|l|
        l.gsub! 00.chr, ''
        l.tr! "@%-", "$$_"
        c.puts l
        if l =~ /{(\S+)}/
          ov = $1
          rv = params[ov.upcase] || ov  #  calculation for ov like (6u*20u) should be implemented
          l.sub! "{#{ov}}", rv
        end
        puts "l=#{l}"
        if block_given?
          nl = yield(l)
          if nl != l
            print "=> #{nl}"
            l = nl
          end
        end
        # if l=~ /(\S+)@or1_stdcells_v1/
        #  cells << $1 unless cells.include? $1
        #  l.sub! '@', '$'
        # elsif l =~ /^ *\.inc/ || l =~ /^ *([iI]|[vV])/
        #   l.sub! /^/, '*'
        #  els
        if l =~ /^\.ends/
          subckt_paras = []
          inside_subckt = false
          desc << '***' if comment_subckt
          comment_subckt = false
        elsif l=~/^\.subckt *(\S+)/
          subckt_name = $1
          inside_subckt = true
          subckt_params = l.scan /(\S+)=(\S+)/
          if subckt_name.upcase == cell.name.upcase
            circuit_top = subckt_name
          else
            circuit_top ||= subckt_name
          end
          puts "subcircuit: #{$1}"
          if (pattern = settings[:dump_subckt_model]) && subckt_name =~ /#{pattern}/
            comment_subckt = true
            puts '===> *** commented out'
          end
        elsif l=~/^(([mM]\S+) *\S+ *\S+ *\S+ *\S+ *(\S+)) *(.*)/
          body = $1
          name=$2
          others = ($4 && $4.upcase)
          subckt_params.each{|a, b| puts others.sub!(/=#{a}/, "=#{b}")}
          model = $3
          # device_class['NMOS'] = model if model && model.upcase =~ /NCH|NMOS/
          # device_class['PMOS'] = model if model && model.upcase =~ /PCH|PMOS/
          p = {}
          others && others.split.each{|equation|
            if equation =~ /(\S+) *= *{(\S+)}/
              ov = $2
              p[$1] = params[ov.upcase] || ov
            elsif equation =~ /(\S+) *= *(\S+)/
              p[$1] = params[$2] || $2
            end
          }
          if p['M'] && p['M'] > "1"
            if p['W'] =~ /([^U]+) *(U*)/
              new_w  = "#{$1.to_f * p['M'].to_f}#{$2}"
              puts "Caution for #{name}: w=#{p['W']} replaced with w=#{new_w} because m=#{p['M']}"
              p['W'] = new_w
              p['M'] = '1'
            end
          end   
          # others = p.map{|a| "#{a[0]}=#{a[1]}"}.join ' '
          others = "l=#{p['L']} w=#{p['W']}" # supress other parameters like as, ps, ad and pd
          others << " m=#{p['M']}" if p['M']
          l = "#{body} #{others}\n"
        elsif l =~ /^ *([rR]|[cC]|[dD])/ || l.downcase =~ /^ *\.(global|subckt|ends)/
          subckt_params.each{|a, b| puts l.sub!(/ #{a} /, " #{b} ")}
        elsif  !inside_subckt && l =~ /^ *[xX]/
            circuit_top ||= '.TOP'
        else
          l.sub! /^/, '*' if !(l =~ /^ *\+/) || prev_line =~ /^ *\*/ # comment
        end
        break if l.upcase.strip == '.END'
        prev_line = l
        desc << '***' if comment_subckt
        desc << l.upcase if l
      }
      circuit_top = circuit_top ? circuit_top.upcase : '.TOP'
      puts "circuit_top => #{circuit_top}"
      c.close
      File.open(reference, 'w:UTF-8'){|f| 
        f.puts desc
        f.puts '.GLOBAL 0'
        f.puts '.END'
      }
      # slink = File.join('lvs_work', reference+'.txt')
      # File.delete slink if File.exist?(slink) 
      # if /mswin32|mingw/ =~ RUBY_PLATFORM
      #   File.link reference, slink
      # else
      #   File.symlink "../#{File.basename reference}", slink
      # end

      puts "#{reference} created under #{Dir.pwd}"
      ['macros', 'pymacros', 'python', 'ruby', 'drc'].each{|f| FileUtils.rm_rf f if File.directory? f}
      if cells.size > 0
        or1_cells = %[an21 an31 an41 buf1 buf2 buf4 buf8 cinv clkbuf1 clkbuf2 clkinv1 clkinv2 dff1 exnr exor
                     inv1 inv1 ~inv2 inv4 inv8 na21 na212 na222 na31 na41 nr21 nr212 nr222 nr31 or21 or31
                     rff1 sdff1 sff1 srff1 ssff1]
        File.open('lvs_work/lvs_settings.rb', 'w'){|f|
          f.puts 'def lvs_settings'
          f.puts "  same_circuits '#{cell.name}', '#{circuit_top ? circuit_top.upcase : '.TOP'}'"
          cells.each{|c|
            if or1_cells.include? c
              f.puts "  same_circuits '#{c}', '#{c.upcase}$OR1_STDCELLS_V1'"
            end
          }
          f.puts "  netlist.make_top_level_pins"
          f.puts "  netlist.flatten_circuit 'Nch*'"
          f.puts "  netlist.flatten_circuit 'Pch*'"
          f.puts 'end'
        }
      end
      unless File.exist? "lvs_work/#{target}_lvs_settings.rb"
        set_settings cell, circuit_top, device_class, "lvs_work/#{target}_lvs_settings.rb", settings
      end
    end
  end

  def set_settings cell, circuit_top, device_class, file, settings
    cell_name = cell.name
    File.open(file, 'w'){|f|
      if  settings[:exclude_layer]
        ln, dt = settings[:exclude_layer]
        blank_layout = settings[:blank_layout]
        f.puts "def set_blank_layout layer_number=#{ln}, data_type=#{dt}"
        f.puts "  source.layout.technology_name='#{cell.layout.technology_name}'"
        f.puts "  unless source.cell_name == '#{cell_name}'"
        f.puts '    raise "Invalid set_blank_layout for #{source.path}[#{source.cell_name}]"'
        f.puts '  end'
        if blank_layout
          f.puts "  blank_layout = '#{blank_layout}'" 
        else
          f.puts "  blank_layout = nil"
        end
        f.puts '  if blank_layout'
        f.puts '    dh = MinedaCommon::DRC_helper.new'
        f.puts '    dh.find_cells_to_exclude [layer_number, data_type], blank_layout, 0'
        f.puts '    exclude = input layer_number, data_type'
        f.puts '  else'
        f.puts '    exclude = input'
        f.puts '  end'
        f.puts 'end'
      end
      f.puts 'def lvs_settings'
      f.puts "  same_circuits '#{cell_name}', '#{circuit_top ? circuit_top.upcase : '.TOP'}'" if cell_name
      f.puts "  netlist.make_top_level_pins"
      settings[:flatten_circuit] && settings[:flatten_circuit].each{|c|
        f.puts "  netlist.flatten_circuit '#{c}'"
      }
      f.puts "  align"
      settings[:device] && device_class.merge!(settings[:device])
      device_class.each_pair{|p, q|
        f.puts "  same_device_classes '#{p}', '#{q.upcase}'" if q
      }
      settings[:tolerance] && settings[:tolerance].each_pair{|d, spec|
        spec.each_pair{|p, v|
          specs = []
          v.each_pair{|name, tol|
            case name
            when :relative
              specs << ':relative => ' + tol.to_s
            when :absolute
              specs << ':absolute => ' + tol.to_s
            end
          }
          f.puts "  tolerance '#{d}', '#{p}', #{specs.join(', ')}"
        }
      }
      f.puts "  netlist.combine_devices"
      f.puts "  schematic.combine_devices"
      f.puts 'end'
    }
  end
end

if nil && $0 == __FILE__
  settings = {
    device: {HRES: 'RES', RES: 'RES'},
    tolerance: {HRES: {R: {relative: 0.03}},
                RES: {L: {relative: 0.03}, W: {relative: 0.03}},                
                CAP: {C: {relative: 0.03, absolute: 1e-15}}},
    flatten_circuit: ['Nch*', 'Pch*', 'R_poly*', 'HR_poly']
  }
  MinedaLVS.new.set_settings nil, nil, {}, '/dev/stdout', settingsend
end
