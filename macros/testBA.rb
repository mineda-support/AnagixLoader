module MyBa
  class BA
    def initialize # file
      app = RBA::Application.instance
      @mw = app.main_window
      @cv = @mw.current_view.active_cellview  
      @ba_type = '*unknown*'
      ba_file = @cv.filename.sub(/\..*/,'_ba.yaml')
      @converted = []
      if File.exist? ba_file
        @ba = YAML.load File.read(ba_file)
        @ba_type = '*final*'
      else
        ba_file = @cv.filename.sub(/\..*/,'_table.yaml')
        if File.exist? ba_file
          initialize_ba_data ba_file
          @ba_type = '*initial*'
        end
      end
      if @ba_type == '*unknown*'
        raise "Error: both #{@cv.filename.sub(/\..*/,'_ba.yaml')} and @{@cv.filename.sub(/\..*/,'_table.yaml')} do not exist!"
      end
      @converted = []
      netlist = File.read file = "c:/Users/seijirom/work/PORTING_TEST/DynSft/SerPar_tb.asc"
      Dir.chdir(File.dirname file){
        ba_final netlist
      }
    end
    def ba_final netlist
      #puts ba.inspect
      new_netlist = ''
      symbol = prefix = id = dc = current = symattr = nil
      netlist.each_line{|l|
        if l =~ /^SYMBOL (\S+)/
          puts symbol
          symbol = $1
          # new_netlist << update_symattr_final(symattr, current, prefix, id, ba_data)
          symattr = {}
        elsif l =~ /^SYMATTR InstName X(\d+)/
          id = $1
          cell = "#{symbol}.asc"
          unless @converted.include? cell
            #data = ba_data['X' + id] || ba_data[symbol.upcase] || ba_data
            puts "Dive into #{cell} at X#{id}"
            ba_final File.read(cell)
            @converted << cell
          end
        elsif l =~ /^SYMATTR InstName (\w)(\d+)/
          prefix = $1
          id = $2
          symattr[:InstName] = l
          next
        elsif l =~ /^SYMATTR Value2 (.*)$/
          current = $1
          symattr[:Value2] = l
          next
        end
        new_netlist << l
      }
    end
  end
  BA.new
end