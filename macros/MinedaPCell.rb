# coding: utf-8
# MinedaPCell v0.781 Jan. 5th 2023 copy right S. Moriyama (Anagix Corporation)
#
#include MinedaPCellCommonModule
module MinedaPCell
  version = '0.781'
  include MinedaPCellCommonModule
  # The PCell declaration for the Mineda MOSFET
  class MinedaMOS < MinedaPCellCommon

    include RBA
    def initialize
      # Important: initialize the super class
      super
      param(:n, TypeInt, "Number of fingers", :default => 1)
      param(:no_finger_conn, TypeBoolean, "No finger connections", :default => false)
    end

    def coerce_parameters_impl

      # We employ coerce_parameters_impl to decide whether the handle or the
      # numeric parameter has changed (by comparing against the effective
      # radius ru) and set ru to the effective radius. We also update the
      # numerical value or the shape, depending on which on has not changed.
    end

    # default implementation
    def can_create_from_shape_impl
      false
    end

    def parameters_from_shape_impl
    end

    def transformation_from_shape_impl
      # I「Create PCell from shape（形状からPCellを作成）」プロトコルを実装します。
      # 変形を決定するために、図形のバウンディングボックスの中心を使用します。
      Trans.new(shape.bbox.center)
    end

    def coerce_parameters_impl
      set_wtot(w*n)
    end

    def produce_impl_core indices, vs, u1, params = {}
      oo_layout_dbu = 1 / layout.dbu
      gw = (w * oo_layout_dbu).to_i
      gl = (l*oo_layout_dbu).to_i
      vo = params[:vs_overhead] || 0
      dgl = ((dg || 0.0)*oo_layout_dbu).to_i
      vs_extra = params[:vs_extra] || 0
      if gw < vs + vs_extra - vo  # dgl: dumbbell gap length
        dgl = [dgl, ((dsl*oo_layout_dbu).to_i - gl)/2].max if defined? dsl # dsl: minimum dumbbell shaft length
      else
        dgl = [dgl,  ((sdg*oo_layout_dbu).to_i - gl)/2].max if defined? sdg # sdg: minimum source-drain gap
      end
      if defined?(soi_bridge) && soi_bridge && defined?(sdg)
        dgl = ([gl,  (sdg*oo_layout_dbu).to_i].max - gl)/2
      end
      xshift = params[:xshift] || vs/2
      yshift = params[:yshift] || vs/2
      u1cut = params[:u1cut] || 0
      gate_ext = params[:gate_ext] || vs/2 + u1/8
      sd_width = [gw, vs + vs_extra].max
      offset = 0
      m1cnt_width = params[:m1cnt_width] || vs
      (n+1).times{|i|
        x = offset + vs/2 - xshift
        create_path(indices[:m1], x, vs-yshift+u1, x, vs-yshift+u1-u1cut+sd_width, m1cnt_width, 0, 0)
        create_path(indices[:li1], x, vs-yshift+u1, x, vs-yshift+u1-u1cut+sd_width, u1, 0, 0) if indices[:li1]
        create_dcont(indices[:dcont], x, vs-yshift+u1, x, vs-yshift+u1+sd_width, vs + vs_extra, params[:dcont_offset])
        x = x + vs/2 + gl/2 + dgl
        if i < n
          create_path(indices[:pol], x, vs-yshift+u1, x, vs-yshift+u1+sd_width, gl, gate_ext, gate_ext)
          if indices[:gate_impl]
            gim = params[:gate_impl_margin] || vs/2
            create_path(indices[:gate_impl], x, vs-yshift+u1, x, vs-yshift+u1+sd_width, gl+gim*2, gate_ext+gim, gate_ext+gim)
          end
        end
        offset = offset + vs + gl + 2*dgl
      }
      if gw > vs + vs_extra
        create_box indices[:diff], -xshift, vs-yshift+u1, offset - gl - 2*dgl - xshift, vs-yshift+u1-u1cut+gw
      else
        create_box indices[:diff], -xshift, vs-yshift+u1+(vs+vs_extra)/2-gw/2, offset - gl - 2*dgl - xshift, vs-yshift+u1-u1cut+gw+(vs+vs_extra)/2-gw/2
      end
      yield -xshift, -yshift, vs*2+gl-xshift, (vs+u1)*2+sd_width-yshift, gl, gw, dgl
    end

    def library_cell name, libname, layout
      if cell = layout.cell(name)
        return cell.cell_index
      else
        lib = Library::library_by_name libname
        cell_index = lib.layout.cell_by_name(name)
        proxy_index = layout.add_lib_cell(lib, cell_index)
      end
    end
  end

  class MinedaNch < MinedaMOS
    include RBA

    def display_text_impl naame='Nch'
      "#{name}\r\n(L=#{l.round(3)}um,W=#{w.round(3)}um,n=#{n.to_s},Total W=#{wtot.round(3)}um)"
    end

    def produce_impl indices, vs, u1, params = {} # NMOS
      produce_impl_core(indices, vs, u1, params){|x1, y1, x2, y2, gl, gw, dgl|
        # create ncon
        wm_offset = wide_metal ? u1 : 0
        via_offset = params[:via_offset] || 0
        x = x1 + vs/2
        pcont_dy = params[:pcont_dy] || u1/4
        y = y2 - vs/2 + pcont_dy
        gate_ext = params[:gate_ext] || 0
        mw1 = params[:m1_width] || u1
        if wide_metal
          x = x - u1
          y = y + u1/2
        end
        if with_pcont
          pol_width = params[:pol_width] || u1 + u1/4
          if n == 1 && !with_sdcont
            insert_cell indices[:pcont], x1+vs+dgl+gl/2, y
            insert_cell indices[:via], x1+vs+dgl+gl/2, y if with_via
            pol_width = [gl, vs/2].max if pol_width > gl            
            x3 = x1+vs+pol_width/2+dgl
            create_path indices[:pol], x3, y, x3, y2-vs + gate_ext - u1, pol_width, 0,0
          else
            pcont_inst = insert_cell indices[:pcont], x, y
            pcont_size = pcont_inst.bbox.width
            insert_cell indices[:via], x, y if with_via
            y = y - pcont_size/2 + pol_width/2
            x3 = x1+vs+pol_width/2+dgl
            create_path2 indices[:pol], x, y, x3, y, x3, y2-vs + gate_ext - u1, pol_width, 0, 0
          end
        end
        offset = x1
        top = nil
        bottom = nil
        prev_pol = nil
        (n+1).times{|i|
          x = offset + vs/2
          y = y2 - vs + u1/2 + gate_ext - u1
          unless no_finger_conn
            create_path indices[:pol], prev_pol-vs/2-gl-dgl, y , x-vs/2-dgl, y, u1, 0, 0 if prev_pol
          end
          prev_pol = x if i >= 1
          if i % 2 == 0
            # first s/d and via
            y = y1+vs/2 - wm_offset -via_offset
            if !no_finger_conn && (with_sdcont || n != 1)
              insert_cell indices[:via], x, y if with_via && with_sdcont  
              create_path indices[:m1], x, y, x, y1+vs+2*u1, mw1, 0, 0
            end
            if top
              create_path indices[:m1], top, y, x, y, mw1, mw1/2, mw1/2 unless no_finger_conn
            end
            top = x
          else
            # second s/d and via
            if n == 1
              insert_cell indices[:via], x, y2-vs/2 + (wide_metal ? u1/2 : 0) + via_offset if with_via && with_sdcont
              y = y2-vs/2
            else
              insert_cell indices[:via], x, y2+u1-vs/2 + via_offset if with_via && with_sdcont && !no_finger_conn
              y = y2+u1-vs/2
            end
            unless no_finger_conn
              create_path indices[:m1], x, y2-vs-2*u1 - wm_offset - via_offset, x, y, mw1, 0, 0 if with_sdcont || n != 1
            end
            if bottom
              y = y2+u1-vs/2
              create_path indices[:m1], bottom, y, x, y, mw1, mw1/2, mw1/2 unless no_finger_conn
            end
            bottom = x
          end
          offset = offset + vs + gl + 2*dgl
        }
        offset = offset - 2*dgl
        # psubcont and via
        psubcont_dx = params[:psubcont_dx] || 0
        psubcont_dy = params[:psubcont_dy] || u1/2 + u1
        x = offset - gl - vs/2 + (with_via ? u1/2 : u1/4) + psubcont_dx
        if with_psubcont && use_pwell
          if n % 2 == 0
            y = y2 - vs/2 + psubcont_dy
          else
            y = y1 + vs/2 - psubcont_dy
            y = y - u1/2 if wide_metal
          end
          insert_cell indices[:psubcont], x, y if indices[:psubcont]
          insert_cell indices[:via], x, y if with_via
        end
        #create_box indices[:narea], x1-u1, y1+vs+u1/2, offset-gl+u1, y2-vs-u1/2
        narea_bw = params[:narea_bw] || u1 + u1/4
        create_box indices[:narea], x1-narea_bw, y1+vs+u1-narea_bw, offset-gl+narea_bw, y2-vs-u1+narea_bw
        # create_box indices[:lvhvt], x1-narea_bw, y1+vs+u1-narea_bw, offset-gl+narea_bw, y2-vs-u1+narea_bw if indices[:lvhvt]
        create_box indices[:nhd], x1-narea_bw, y1+vs+u1-narea_bw, offset-gl+narea_bw, y2-vs-u1+narea_bw if indices[:nhd] # special for PTS06
        delta = params[:nex_delta] || u1*5
        if indices[:nex]
          create_box indices[:nex], x1-delta, y1+vs-u1/2-delta-u1, offset-gl+delta, y2-vs+u1/2+delta+u1
          delta = delta + delta
          create_box indices[:ar], x1-delta, y1+vs-u1/2-delta-u1, offset-gl+delta, y2-vs+u1/2+delta+u1 if indices[:ar]
        end
        if indices[:pwl] && use_pwell
          if one = params[:pwl_bw] #        one = u1*6.25
            if indices[:nex]
              create_box indices[:pwl], x1-delta-one, [y1+vs-u1/2-delta-u1-one, y2-vs+u1/2+delta+u1-4*one].min,
                    [offset-gl+delta+one, x1-delta+4*one].max, y2-vs+u1/2+delta+u1+one
            else
              create_box indices[:pwl], x1-delta-one, y1+vs+u1-delta-one, offset-gl+delta+one, y2-vs-u1+delta+one
            end
          end
        end
      }
    end
  end

  class MinedaNch_SOI < MinedaMOS
    include RBA

    def produce_impl indices, vs, u1, params = {} # NMOS_SOI
      produce_impl_core(indices, vs, u1, params){|x1, y1, x2, y2, gl, gw, dgl|
        # create ncon
        wm_offset = wide_metal ? u1 : 0
        
        x = x1 + vs/2
        pcont_dy = params[:pcont_dy] || u1/4
        y = y2 - vs/2 + pcont_dy
        gate_ext = params[:gate_ext] || 0
        if wide_metal
          x = x - u1
          y = y + u1/2
        end
        if with_pcont
          pol_width = params[:pol_width] || u1 + u1/4
          if n == 1 && !with_sdcont
            insert_cell indices[:pcont], x1+vs+dgl+gl/2, y
            insert_cell indices[:via], x1+vs+dgl+gl/2, y if with_via
            create_path indices[:pol], x1+vs+dgl+gl/2, y, x1+vs+dgl+gl/2, y2-vs + gate_ext - u1, pol_width, 0,0
          else
            insert_cell indices[:pcont], x, y
            insert_cell indices[:via], x, y if with_via
            y = y #- u1/2 # necessary to eliminate POL gap error
            x0 = x1+vs+u1/2+dgl
            unless no_finger_conn
              if defined?(soi_bridge) && soi_bridge
                create_path2 indices[:m1], x, y, x0+u1, y, x0+u1, y2-vs + gate_ext - u1, pol_width, 0, 0
              else
                create_path2 indices[:pol], x, y, x0, y, x0, y2-vs + gate_ext - u1, pol_width, 0, 0
              end
            end
          end
        end
        offset = x1
        top = nil
        bottom = nil
        prev_pol = nil
        (n+1).times{|i|
          x = offset + vs/2
          y = y2 - vs + u1/2 + gate_ext - u1
          pol_width = params[:pol_width] || u1
          unless no_finger_conn
            if defined?(soi_bridge) && soi_bridge # NOTE: gate_contact_space + u1 = gl + dgl*2
              create_path indices[:pol], prev_pol-vs-gl-dgl*2, y+u1/2, x-vs-u1/2, y+u1/2, pol_width, 0, 0 if prev_pol
            else
              create_path indices[:pol], prev_pol-vs/2-gl-dgl*2, y, x-vs/2-dgl, y, pol_width, 0, 0 if prev_pol
            end
          end
          if defined?(body_tie) && body_tie && i < n
            create_path indices[:tin_block], x + vs/2, vs - u1/2 - u1/4,  x + vs/2  + gl + dgl*2, vs - u1/2 - u1/4, u1 + u1/2, 0, 0
            xstop = x + gl + dgl*2 + vs
            xstop = xstop + vs + u1 + u1/8 if i < n-1 || n % 2 ==  0
            xstart = x + vs/2 + gl/2 + dgl
            create_path2 indices[:diff], xstart, vs + u1, xstart, u1/4, xstop, u1/4, u1 + u1/2, 0, 0
            create_path indices[:pwell],  xstart, y1+vs,  xstart, y1+vs/2+u1/2-u1/8, u1 + u1 + u1/2, 0, 0
          end
          prev_pol = x if i >= 1
          if i % 2 == 0
            # first s/d and via
            y = y1+vs/2 - wm_offset
            if with_sdcont || n != 1
              insert_cell indices[:via], x, y if with_via && with_sdcont
              create_path indices[:m1], x, y, x, y1+vs+2*u1, pol_width, 0, 0
            end
            if top
              create_path indices[:m1], top, y, x, y, pol_width, u1/2, u1/2 unless no_finger_conn
            end
            top = x
          else
            # second s/d and via
            # create_path indices[:m1], x, y2-vs-2*u1 - wm_offset, x, y2+u1-vs/2, u1, 0, 0 if with_sdcont || n != 1
            if defined?(soi_bridge) && soi_bridge
              if n == 1 || (n == 2 && i == 1)
                y = y2-u1/4-vs/2
              else
                y = y2+pol_width+u1/8
              end
            else
              if n == 1 || (n == 2 && i == 1)
                y = y2-vs/2
              else
                y = y2+u1-vs/2
              end
            end
            if n == 1
              insert_cell indices[:via], x, y2-vs/2 + (wide_metal ? u1/2 : 0) if with_via && with_sdcont
            else
              insert_cell indices[:via], x, y if with_via && with_sdcont
            end
            create_path indices[:m1], x, y2-vs-2*u1 - wm_offset, x, y, pol_width, 0, 0 if with_sdcont || n != 1
            if bottom && !no_finger_conn
              if defined?(soi_bridge) && soi_bridge
                create_path indices[:m1], bottom, y, x, y, pol_width+u1/4, 0, 0
              else
                create_path indices[:m1], bottom, y, x, y, pol_width, pol_width/2, pol_width/2
              end
            end
            bottom = x
          end

          if i < n
            #create_path(indices[:pol], x, vs, x, vs+u1+gw + u1, gl, 0, 0)
            if defined?(soi_bridge) && soi_bridge
              x = x + vs/2 + gl/2 + dgl
              insert_cell indices[:pcont], x, [u1+gw, vs+u1+vs/2].max
              insert_cell indices[:pcont], x, vs+u1+gw +vs/2 + u1 if i > 0
              create_path indices[:m1], x, [u1+gw, vs+u1+vs/2].max, x, vs+u1+gw +vs/2 + u1, vs, 0, 0
            end
          end
          offset = offset + vs + gl + 2*dgl
        }
        if defined?(body_tie) && body_tie
          y = y1 + vs/2
          x = offset - 2*dgl - gl - vs/2
          x = x + vs + u1 if n % 2 == 0
          insert_cell indices[:dcont], x, y - u1 - u1/4
          # insert_cell indices[:diff], x, y - u1 - u1/4
          create_box indices[:diff], x - vs/2, y - u1 - u1/4 - vs/2, x + vs/2, y - u1 - u1/4 + vs/2
          create_box indices[:parea], x1 + vs -u1/2- u1/8, y + u1/2 - u1/8, x + vs/2 + u1/2, y - 3*u1 + u1/8
          create_box indices[:pwell], x1 + vs -u1- u1/8, y + u1 + u1/8 , x + vs/2 + u1, y - 3*u1 + u1/8-u1/2
        end
        offset = offset - 2*dgl
        # psubcont and via
        psubcont_dx = params[:psubcont_dx] || 0
        psubcont_dy = params[:psubcont_dy] || u1/2 + u1
        x = offset - gl - vs/2 + (with_via ? u1/2 : u1/4) + psubcont_dx
        if with_psubcont && use_pwell
          if n % 2 == 0
            y = y2 - vs/2 + psubcont_dy
          else
            y = y1 + vs/2 - psubcont_dy
            y = y - u1/2 if wide_metal
          end
          insert_cell indices[:psubcont], x, y if indices[:psubcont]
          insert_cell indices[:via], x, y if with_via
        end
        #create_box indices[:narea], x1-u1, y1+vs+u1/2, offset-gl+u1, y2-vs-u1/2
        narea_bw = params[:narea_bw] || u1 + u1/4
        if indices[:pwell]
          create_box indices[:pwell], x1-narea_bw, y1+vs+u1-narea_bw, offset-gl+narea_bw, y2-vs-u1+narea_bw
          create_box indices[:narea], x1-narea_bw+u1/2, y1+vs+u1-narea_bw+u1/2, offset-gl+narea_bw-u1/2, y2-vs-u1+narea_bw-u1/2
          # create_box indices[:lvhvt], x1-narea_bw+u1/2, y1+vs+u1-narea_bw+u1/2, offset-gl+narea_bw-u1/2, y2-vs-u1+narea_bw-u1/2 if indices[:lvhvt]
        else
          create_box indices[:narea], x1-narea_bw, y1+vs+u1-narea_bw, offset-gl+narea_bw, y2-vs-u1+narea_bw
          # create_box indices[:lvhvt], x1-narea_bw, y1+vs+u1-narea_bw, offset-gl+narea_bw, y2-vs-u1+narea_bw if indices[:lvhvt]

        end

        create_box indices[:nhd], x1-narea_bw, y1+vs+u1-narea_bw, offset-gl+narea_bw, y2-vs-u1+narea_bw if indices[:nhd] # special for PTS06
        if indices[:nex]
          delta = params[:nex_delta] || u1*5
          create_box indices[:nex], x1-delta, y1+vs-u1/2-delta-u1, offset-gl+delta, y2-vs+u1/2+delta+u1
          delta = delta + delta
          create_box indices[:ar], x1-delta, y1+vs-u1/2-delta-u1, offset-gl+delta, y2-vs+u1/2+delta+u1 if indices[:ar]
        end
        if indices[:pwl] && use_pwell
          if one = params[:pwl_bw] #        one = u1*6.25
            if indices[:nex]
              create_box indices[:pwl], x1-delta-one, [y1+vs-u1/2-delta-u1-one, y2-vs+u1/2+delta+u1-4*one].min,
                     [offset-gl+delta+one, x1-delta+4*one].max, y2-vs+u1/2+delta+u1+one
            else
               create_box indices[:pwl], x1-delta-one, y1+vs+u1-delta-one, offset-gl+delta+one, y2-vs-u1+delta+one
            end
          end
        end
      }
    end
  end

  class MinedaPch < MinedaMOS
    include RBA

    def display_text_impl name='Pch'
      "#{name}\r\n(L=#{l.round(3)}um,W=#{w.round(3)}um,n=#{n.to_s},Total W=#{wtot.round(3)}um)"
    end

    def produce_impl indices, vs, u1, params = {} # PMOS
      produce_impl_core(indices, vs, u1, params){|x1, y1, x2, y2, gl, gw, dgl|
        # create pcont
        wm_offset = wide_metal ? vs/2 : 0
        via_offset = params[:via_offset] || 0
        x = x1 + vs/2
        pcont_dy = params[:pcont_dy] || -u1/4
        y = y1 + vs/2 + pcont_dy
        gate_ext = params[:gate_ext] || 0
        mw1 = params[:m1_width] || u1
        if wide_metal
          x = x - u1
          y = y - u1/2
        end
        if with_pcont
          pol_width = params[:pol_width] || u1 + u1/4
          pol_width = [gl, vs/2].max if pol_width > gl
          if n == 1 && !with_sdcont
            insert_cell indices[:pcont], x1+vs+dgl+gl/2, y
            insert_cell indices[:via], x1+vs+dgl+gl/2, y if with_via
            x3 = x1+vs+pol_width/2+dgl
            create_path indices[:pol], x3, y, x3, y1+vs - gate_ext + u1, pol_width, 0,0
          else
            pcont_inst = insert_cell indices[:pcont], x, y
            pcont_size = pcont_inst.bbox.width
            insert_cell indices[:via], x, y if with_via
            y = y + pcont_size/2 - pol_width/2
            x3 = x1+vs+pol_width/2+dgl
            create_path2 indices[:pol], x, y, x3, y, x3, y1+vs - gate_ext + u1, pol_width, 0, 0
          end
        end
        offset = x1
        top = nil
        bottom = nil
        prev_pol = nil
        (n+1).times{|i|
          x = offset + vs/2
          y = y1 + vs - u1/2 - gate_ext + u1 ### y1 + u1/2 + vs/2 #
          unless no_finger_conn
            create_path indices[:pol], prev_pol-vs/2-gl-dgl, y, x-vs/2-dgl, y, u1, 0, 0 if prev_pol
          end
          prev_pol = x  if i >=1
          if i % 2 == 0
            # first s/d and via
            if !no_finger_conn && (with_sdcont || n != 1)
              insert_cell indices[:via], x, y2-vs/2 + wm_offset + via_offset if with_via && with_sdcont
              create_path indices[:m1], x, y2-vs-2*u1, x, y2-vs/2 + wm_offset + via_offset, mw1, 0, 0
            end
            if top
              y = y2-vs/2 + wm_offset + via_offset
              create_path indices[:m1], top, y, x, y, mw1, mw1/2,mw1/2 unless no_finger_conn
            end
            top = x
          else
            # second s/d and via
            if n == 1
              insert_cell indices[:via], x, y1+vs/2 - (wide_metal ? u1/2 : 0) - via_offset if with_via && with_sdcont
              y = y1 + vs/2
            else
              insert_cell indices[:via], x, y1-u1+vs/2 - via_offset if with_via && with_sdcont && !no_finger_conn
              y = y1-u1+vs/2
            end
            create_path indices[:m1], x, y, x, y1+vs+2*u1, mw1, 0, 0 if !no_finger_conn && (with_sdcont || n != 1)
            if bottom && !no_finger_conn
              create_path indices[:m1], bottom, y1-u1+vs/2, x, y1 -u1+vs/2, mw1, mw1/2, mw1/2
            end
            bottom = x
          end
          offset = offset + vs + gl + 2*dgl
        }
        offset = offset - 2*dgl
         # nsubcont and via
        if with_nsubcont && use_nwell
          nsubcont_dx = params[:nsubcont_dx] || 0
          nsubcont_dy = params[:nsubcont_dy] ||  u1/2 + u1
          x = offset - gl - vs/2 + (with_via ? u1/2 : 0) + nsubcont_dx
          if n % 2 == 0
            y = y1 + vs/2 - nsubcont_dy - (wide_metal ? u1 : 0)
          else
            y = y2 - vs/2 + nsubcont_dy + wm_offset
          end
          y = y + u1/2 if wide_metal
          x = x + u1/2 if n > 1
          insert_cell indices[:nsubcont], x, y if indices[:nsubcont]
          insert_cell indices[:via], x, y if with_via
        end
        parea_bw = params[:parea_bw] || u1 + u1/4
        create_box indices[:parea], x1-parea_bw, y1+vs+u1-parea_bw, offset-gl+parea_bw, y2-vs-u1+parea_bw
        # create_box indices[:lvhvt], x1-parea_bw, y1+vs+u1-parea_bw, offset-gl+parea_bw, y2-vs-u1+parea_bw if indices[:lvhvt]
        delta = params[:pex_delta] || u1*5
        create_box indices[:pex], x1-delta, y1+vs-u1/2-delta-u1, offset-gl+delta, y2-vs+u1/2+delta+u1 if indices[:pex]
        delta = delta + delta
        create_box indices[:ar], x1-delta, y1+vs-u1/2-delta-u1, offset-gl+delta, y2-vs+u1/2+delta+u1 if indices[:ar]
        if indices[:nwl] && use_nwell
          if one = params[:nwl_bw] #         one = u1*6.25
            if indices[:pex]
              create_box indices[:nwl],  x1-delta-one, y1+vs-u1/2-delta-u1-one, [offset-gl+delta+one, x1-delta+4*one].max,
                     [y2-vs+u1/2+delta+u1+one, y1+vs-u1/2-delta-u1+4*one].max # just for tiascr130?
            else
              create_box indices[:nwl],  x1-delta-one, y1+vs+u1-delta-one, offset-gl+delta+one, y2-vs-u1+delta+one
            end
          else
            if n % 2 == 0
              create_box indices[:nwl], x1-vs, y1-u1-u1/2, offset-gl +2*u1, y2
            else
              create_box indices[:nwl], x1-vs, y1, offset-gl +2*u1, y2+u1+u1/2
            end
          end
        end
      }
    end
  end

  class MinedaPch_SOI < MinedaMOS
    include RBA

    def produce_impl indices, vs, u1, params = {} # PMOS_SOI
      produce_impl_core(indices, vs, u1, params){|x1, y1, x2, y2, gl, gw, dgl|
        # create pcont
        wm_offset = wide_metal ? vs/2 : 0
        x = x1 + vs/2
        pcont_dy = params[:pcont_dy] || -u1/4
        y = y1 + vs/2 + pcont_dy
        gate_ext = params[:gate_ext] || 0
        if wide_metal
          x = x - u1
          y = y - u1/2
        end
        if with_pcont
          pol_width = params[:pol_width] || u1 + u1/4
          if n == 1 && !with_sdcont
            insert_cell indices[:pcont], x1+vs+dgl+gl/2, y
            insert_cell indices[:via], x1+vs+dgl+gl/2, y if with_via
            create_path indices[:pol], x1+vs+dgl+gl/2, y, x1+vs+dgl+gl/2, y1+vs - gate_ext + u1, pol_width, 0,0
          else
            insert_cell indices[:pcont], x, y
            insert_cell indices[:via], x, y if with_via
            y = y # + u1/2 # necessary to eliminate POL gap error
            x0 = x1+vs+u1/2+dgl
            unless no_finger_conn
              if defined?(soi_bridge) && soi_bridge
                create_path2 indices[:m1], x, y, x0+u1, y, x0+u1, y1+vs - gate_ext + u1, pol_width, 0, 0
              else
                create_path2 indices[:pol], x, y, x0, y, x0, y1+vs - gate_ext + u1, pol_width, 0, 0
              end
            end
          end
        end
        offset = x1
        top = nil
        bottom = nil
        prev_pol = nil
        (n+1).times{|i|
          x = offset + vs/2
          y = y1 + vs - u1/2 - gate_ext + u1 ### y1 + u1/2 + vs/2 #
          pol_width = params[:pol_width] || u1
          unless no_finger_conn
            if defined?(soi_bridge) && soi_bridge # NOTE: gate_contact_space + u1 = gl + dgl*2
              create_path indices[:pol], prev_pol-vs-gl-dgl*2, y-u1/2, x-vs-u1/2, y-u1/2, pol_width, 0, 0 if prev_pol
            else
              # create_path indices[:pol], prev_pol-vs/2-gl-dgl*2, y, x-vs/2-dgl, y, pol_width, 0, 0 if prev_pol
              create_path indices[:pol], prev_pol-vs/2-gl-dgl, y, x-vs/2-dgl, y, pol_width, 0, 0 if prev_pol
            end
          end
          if defined?(body_tie) && body_tie && i < n
            create_path indices[:tin_block], x + vs/2, y2 - (vs - u1/2 - u1/4),  x + vs/2  + gl+dgl*2, y2 - (vs - u1/2 - u1/4), u1 + u1/2, 0, 0
            xstop = x + gl + dgl*2 + vs
            xstop = xstop + vs + u1 + u1/8 if i < n-1 || n % 2 ==  0
            create_path2 indices[:diff], x + vs/2  + (gl+dgl*2)/2, y2-(vs + u1), x + vs/2  + (gl+dgl*2)/2, y2-u1/4,                          xstop, y2-u1/4, u1 + u1/2, 0, 0
          end
          prev_pol = x  if i >=1
          if i % 2 == 0
            # first s/d and via
            y = y2-vs/2 + wm_offset
            if with_sdcont || n != 1
              insert_cell indices[:via], x, y if with_via && with_sdcont
              create_path indices[:m1], x, y2-vs-2*u1, x, y, pol_width, 0, 0
            end
            if top && !no_finger_conn
              create_path indices[:m1], top, y, x, y, pol_width, u1/2, u1/2
            end
            top = x
          else
            # second s/d and via
            if defined?(soi_bridge) && soi_bridge
              if n == 1 || (n == 2 && i == 1)
                y = y1-u1+vs
              else
                y = y1-pol_width-u1/8
              end
            else
              if n == 1 || (n == 2 && i == 1)
                y = y1+vs/2
              else
                y = y1-u1+vs/2
              end
            end
            if n == 1
              insert_cell indices[:via], x, y1+vs/2 - (wide_metal ? u1/2 : 0) if with_via && with_sdcont
            else
              insert_cell indices[:via], x, y if with_via && with_sdcont
            end
            create_path indices[:m1], x, y, x, y1+vs+2*u1, pol_width, 0, 0 if with_sdcont || n != 1
            if bottom && !no_finger_conn
              if defined?(soi_bridge) && soi_bridge
                create_path indices[:m1], bottom, y1-pol_width, x, y1-pol_width, pol_width+u1/4, 0, 0
              else
                create_path indices[:m1], bottom, y1-u1+vs/2, x, y1 -u1+vs/2, pol_width, u1/2, u1/2
              end
            end
            bottom = x
          end

          if i < n
            #create_path(indices[:pol], x, vs, x, vs+u1+gw + u1, gl, 0, 0)
            if defined?(soi_bridge) && soi_bridge
              x = x + vs/2 + gl/2 + dgl
              insert_cell indices[:pcont], x, [y1+vs+vs+u1, y1+vs+u1+gw-vs/2].min
              insert_cell indices[:pcont],  x, y1+vs/2 if i> 0
              create_path indices[:m1], x, y1+vs/2, x,[y1+vs+vs+u1, y1+vs+u1+gw-vs/2].min, vs, 0, 0
            end
          end
          offset = offset + vs + gl + 2*dgl
        }
        if defined?(body_tie) && body_tie
          y = y2 + vs/2
          x = offset - gl-dgl*2 - vs/2
          x = x + vs + u1 if n % 2 == 0
          insert_cell indices[:dcont], x, y - u1
          insert_cell indices[:diff], x, y - u1
          create_box indices[:narea], x1 + vs -u1/2- u1/8, y + u1/2 + u1/8, x + vs/2 + u1/2, y - 3*u1 + u1/4 + u1/8
        end
        offset = offset - 2*dgl
        # nsubcont and via
        if with_nsubcont && use_nwell
          nsubcont_dx = params[:nsubont_dx] || 0
          nsubcont_dy = params[:nsubcont_dy] ||  u1/2 + u1
          x = offset - gl - vs/2 + (with_via ? u1/2 : 0) + nsubcont_dx
          if n % 2 == 0
            y = y1 + vs/2 - nsubcont_dy - (wide_metal ? u1 : 0)
          else
            y = y2 - vs/2 + nsubcont_dy + wm_offset
          end
          y = y + u1/2 if wide_metal
          x = x + u1/2 if n > 1
          insert_cell indices[:nsubcont], x, y if indices[:nsubcont]
          insert_cell indices[:via], x, y if with_via
        end
        parea_bw = params[:parea_bw] || u1 + u1/4
        create_box indices[:parea], x1-parea_bw, y1+vs+u1-parea_bw, offset-gl+parea_bw, y2-vs-u1+parea_bw
        # create_box indices[:lvhvt], x1-parea_bw, y1+vs+u1-parea_bw, offset-gl+parea_bw, y2-vs-u1+parea_bw if indices[:lvhvt]
        delta = params[:pex_delta] || u1*5
        create_box indices[:pex], x1-delta, y1+vs-u1/2-delta-u1, offset-gl+delta, y2-vs+u1/2+delta+u1 if indices[:pex]
        delta = delta + delta
        create_box indices[:ar], x1-delta, y1+vs-u1/2-delta-u1, offset-gl+delta, y2-vs+u1/2+delta+u1 if indices[:ar]
        if indices[:nwl] && use_nwell
          if one = params[:nwl_bw] #         one = u1*6.25
            if indices[:pex]
              create_box indices[:nwl],  x1-delta-one, y1+vs-u1/2-delta-u1-one, [offset-gl+delta+one, x1-delta+4*one].max,
                     [y2-vs+u1/2+delta+u1+one, y1+vs-u1/2-delta-u1+4*one].max # just for tiascr130?
            else
              create_box indices[:nwl],  x1-delta-one, y1+vs+u1-delta-one, offset-gl+delta+one, y2-vs-u1+delta+one
            end
          else
            if n % 2 == 0
              create_box indices[:nwl], x1-vs, y1-u1-u1/2, offset-gl +2*u1, y2
            else
              create_box indices[:nwl], x1-vs, y1, offset-gl +2*u1, y2+u1+u1/2
            end
          end
        end
      }
    end
  end

  class MinedaResistor < MinedaPCellCommon

    include RBA
    def initialize
      # Important: initialize the super class
      super
      param(:with_via, TypeBoolean, "Put Via over contacts", :default => true, :hidden => false)
    end

    # default implementation
    def can_create_from_shape_impl
      false
    end

    def parameters_from_shape_impl
    end

    def transformation_from_shape_impl
      # I「Create PCell from shape（形状からPCellを作成）」プロトコルを実装します。
      # 変形を決定するために、図形のバウンディングボックスの中心を使用します。
      Trans.new(shape.bbox.center)
    end

    def create_contacts indices, w, x0, y, vs, u1, pitch=nil, fill_metal=true
      contact = indices[:pcont] || indices[:dcont] || indices[:nsubcont]
      pitch ||= vs+u1/4  # cnt distance > 5 um
      n = (w/pitch).to_i
      if n <= 1
        insert_cell contact, x0, y, true
        insert_cell indices[:via], x0, y if !defined?(with_via) || with_via
      else
        offset = w- pitch*n
        (x0-w/2 + offset/2 + pitch/2).step(x0+w/2-vs/2, pitch){|x|
          # insert_cell indices, :via, x, y, vs, u1, false
          insert_cell contact, x, y, true
          insert_cell indices[:via], x, y if !defined?(with_via) || with_via
        }
        #create_box indices[:m1], x0-w/2, y-vs/2, x0+w/2, y+vs/2 
        create_box fill_metal, x0-w/2, y-vs/2, x0+w/2, y+vs/2 if fill_metal
        #vs2 = vs + u1/4
        #create_box indices[:m2], x0-w/2, y-vs2/2, x0+w/2, y+vs2/2
      end
    end

    def produce_impl indices, header_outside, vs, u1, params={}
      res_body = indices[:pol] || indices[:diff] || indices[:nwl]
      oo_layout_dbu = 1/ layout.dbu
      rw = (w*oo_layout_dbu).to_i
      rrl = (l*oo_layout_dbu).to_i
      sp = (s*oo_layout_dbu).to_i
      ms = (m*oo_layout_dbu).to_i
      cs = params[:contact_size] || vs
      rrl = rrl - (vs - cs)
      rw_ho = rw*header_outside
      rl = rrl - (sp+rw)*(n-1) -rw_ho
      sl = [(rl/n/u1).to_i*u1, ms-2*rw].min
      if sl*n + (sp+rw)*(n-1) == rrl
        r = 0
      else
        sl = [sl + u1, ms-2*rw].min
        r = rrl - sl*(n-1) - (sp+rw)*(n-1)
        if r <= 0 && sl > ms-2*rw
          rl = rrl - sp*(n-2)
          set_n n - 1
        end
      end
      puts "rw=#{rw}, rrl = #{rrl}, rl = #{rl}, n = #{n}, sp=#{sp}, sl = #{sl}, r = #{r}"
      prev_x = nil
      xmax = ymax = -10000000
      ymin = 10000000
      for i in 0..n-1
        offset = vs/2 + (sp+rw)*i
        r = sl
        if i == n - 1 # rl - sl*(i+1) < 0
          r = rl - sl*i
        end
        puts "offset=#{offset}, r=#{r} for i=#{i}"
        if i % 2 == 0
          x = offset
          if i == 0
            points = [Point::new(x, -rw_ho), Point::new(x, vs+r)]
            y = vs/2-rw_ho
            # insert_cell indices, :via, x, y, vs, u1
            # insert_cell indices, :cnt, x, y, vs, u1
            # insert_cell indices, :diff, x, y, vs, u1
            create_contacts indices, rw, x, y, vs, u1, params[:pitch], res_body
            ymin = [ho ? y + vs/2 : y - vs/2, ymin].min
            points = [Point::new(x, vs-rw_ho-(vs-cs)/2), Point::new(x, vs+r + (vs-cs)/2)]
          else
            points = [Point::new(x, vs-rw_ho), Point::new(x, vs+r + (vs-cs)/2)]
          end
          cell.shapes(indices[:res]).insert(Path::new(points, rw, 0, 0))
          if i == n-1
            points = [Point::new(x, (n == 1 ? -rw_ho : vs)), Point::new(x, vs+r+vs)]
            y =  vs+r+vs/2
            # insert_cell indices, :via, x, y, vs, u1
            # insert_cell indices, :cnt, x, y, vs, u1
            # insert_cell indices, :diff, x, y, vs, u1
            create_contacts indices, rw, x, y, vs, u1, params[:pitch], res_body
            ymax = [y+vs/2, ymax].max
          end
          cell.shapes(res_body).insert(Path::new(points, rw, 0, 0))

          if prev_x
            y = vs - rw/2
            points = [Point::new(x, y), Point::new(prev_x, y)]
            cell.shapes(res_body).insert(Path::new(points, rw, rw/2, rw/2))
            cell.shapes(indices[:res]).insert(Path::new(points, rw, rw/2, rw/2))
            ymax = [y+rw/2, ymax].max
          end
        else
          points = [Point::new(offset, vs+(sl-r)-(vs-cs)/2), Point::new(offset, vs+sl)]
          cell.shapes(indices[:res]).insert(Path::new(points, rw, 0, 0))
          if i == n-1
            points = [Point::new(offset, sl-r), Point::new(offset, vs+sl)]
            x = offset
            y = vs+sl-r-vs/2
            # insert_cell indices, :via, x, y, vs, u1
            # insert_cell indices, :cnt, x, y, vs, u1
            # insert_cell indices, :diff, x, y, vs, u1
            create_contacts indices, rw, x, y, vs, u1, params[:pitch], res_body
            ymax = [y+vs/2, ymax].max
            ymin = [ho ? y+vs/2+u1/4 : y-vs/2, ymin].min
          end
          cell.shapes(res_body).insert(Path::new(points, rw, 0, 0))

          if prev_x
            x = offset
            y = vs + sl + rw/2
            points = [Point::new(x, y), Point::new(prev_x, y)]
            cell.shapes(res_body).insert(Path::new(points, rw, rw/2, rw/2))
            cell.shapes(indices[:res]).insert(Path::new(points, rw, rw/2, rw/2))
            ymax = [y+rw/2, ymax].max
          end
        end
        prev_x = offset
        xmax = [x + [rw/2, vs/2].max, xmax].max
        puts "[xmax,ymax] = #{[xmax,ymax].inspect}"
      end
      # puts "n=#{n}"
      [[[vs/2-rw/2, 0].min, [(ho||n<=2) ? 0 : vs - rw, ymin].min, xmax, ymax], rw_ho]
    end
  end

  class MinedaCapacitor < MinedaPCellCommon
    include RBA
    def initialize
      # Important: initialize the super class --- don't know if this is really necessary
      super
    end

    # default implementation
    def can_create_from_shape_impl
      false
    end

    def transformation_from_shape_impl
      # I「Create PCell from shape（形状からPCellを作成）」プロトコルを実装します。
      # 変形を決定するために、図形のバウンディングボックスの中心を使用します。
      Trans.new(shape.bbox.center)
    end

    def create_contacts_horizontally indices, x1, x2, y0, vs, u1, pitch=nil, fill_metal=true
      pitch ||= vs+u1 # +u1/2+u1/4
      n = ((x2+u1-x1)/pitch).to_i
      offset = x2+u1-x1-pitch*n
      (offset/2 + x1+vs/2..x2-vs/2).step(pitch){|x|
        # insert_cell indices, index, x, y1, vs, u1, fill_metal
        if indices[:pol]
          insert_cell indices[:pcont], x, y0
        else
          insert_cell indices[:dcont], x, y0
        end
        insert_cell indices[:via], x, y0
      }
    end

    def create_contacts_vertically indices, x0, y1, y2, vs, u1, pitch=nil, fill_metal=true
      pitch ||= vs+u1  # +u1/2+u1/4
      n = ((y2+u1-y1)/pitch).to_i
      offset = y2+u1-y1-pitch*n
      (offset/2+y1+vs/2..y2-vs/2).step(pitch){|y|
        # insert_cell indices, index, x1, y, vs, u1, fill_metal
        if indices[:via2]
          insert_cell indices[:via2], x0, y
        else
          if indices[:pol]
            insert_cell indices[:pcont], x0, y
          else
            insert_cell indices[:dcont], x0, y
          end
          insert_cell indices[:via], x0, y
        end
      }
    end

    def instantiate index, x, y
      CellInstArray.new(index, Trans.new(x, y))
    end
  end

  class  MinedaDiff_cap < MinedaCapacitor
    def initialize
      super
      param(:cval, TypeDouble, "Capacitor value", :default => 0, :hidden=> true)
      param(:polcnt_outside, TypeBoolean, "Poly contact outside?", :default => true, :hidden => false)
    end

    def display_text_impl
      # Provide a descriptive text for the cell
      "Diff Capacitor\r\n(L=#{l.round(3)}um,W=#{w.round(3)}um,C=#{cval.to_s})"
    end

    def produce_impl indices, vs, u1, area_index=nil, well_index=nil, params={}
      oo_layout_dbu = 1 / layout.dbu
      cw = (w*oo_layout_dbu).to_i
      cl = (l*oo_layout_dbu).to_i
      u2 = u1 + u1
      cap_ext = params[:cap_ext] || u1
      create_box indices[:diff], 0, -cap_ext, cw, cl+vs+u1+u1/2
      create_box indices[:cap], 0, 0, cw, cl
      # create_box indices[:cap], 0, 0, cw, cl+u1+vs
      diff_enclosure = params[:diff_enclosure] || 0
      create_box area_index, -u1/2, -u1-u1/2, cw + u1/2, cl + u1/2 + vs + u1 + diff_enclosure
      well_diff_enc = params[:wd_enc] || u1*5
      if well_index
        if nsub_cont = indices[:psubcont]
          create_box well_index, [-well_diff_enc, -vs-u1/2-u2].min, -u1-well_diff_enc,
                          cw + well_diff_enc, [cl + well_diff_enc + vs + u1, cl+u2+vs + u2].max
          insert_cell indices[:nsubcont], -vs-u1/2, cl+u2+vs
        else
          x0 = -well_diff_enc
          x0 = [x0, -u2-vs].min if polcnt_outside
          create_box well_index, x0, -u1-well_diff_enc, cw + well_diff_enc, cl + well_diff_enc + vs + u1
        end
      end

      if polcnt_outside
        create_box indices[:pol], -u2-vs, 0, cw + cap_ext, cl
        create_contacts_vertically indices, -u1-vs/2, 0, cl, vs, u1, params[:vpitch], true # false
      else
        create_box indices[:pol], -u1, 0, cw + cap_ext, cl
        create_contacts_vertically indices, u1+vs/2, 0, cl, vs, u1, params[:vpitch], true # false
      end
      indices[:pol] = nil # this tells create_contacts_horizontally to use dcont
      create_contacts_horizontally indices, 0, cw, u1/2+cl+u1, vs, u1, params[:hpitch], true # false
      # insert_cell indices, nsubcont_index, 0, cl+2*u1+vs, vs, u1
      # insert_cell indices, :diff, 0, cl+2*u1+vs, vs, u1
      # insert_cell indices, :cnt, 0, cl+2*u1+vs, vs, u1
      #          points = [Point::new(offset, vs), Point::new(offset, vs/2+r)]
      #          cell.shapes(pol_index).insert(Path::new(points, rw, vs, vs))
      #          cell.shapes(res_index).insert(Path::new(points, rw, vs/4, vs/4))
    end
  end

  class MinedaPoly_cap < MinedaCapacitor
    def initialize
      super
      param(:cval, TypeDouble, "Capacitor value", :default => 0, :hidden=> true)
      param(:polcnt_outside, TypeBoolean, "Poly contact outside?", :default => true, :hidden => false)
    end

    def display_text_impl
      # Provide a descriptive text for the cell
      "Poly Capacitor\r\n(L=#{l.round(3)}um,W=#{w.round(3)}um,C=#{cval.to_s})"
    end

    def produce_impl indices, vs, u1, params = {}
      oo_layout_dbu = 1 / layout.dbu
      cw = (w*oo_layout_dbu).to_i
      cl = (l*oo_layout_dbu).to_i
      u2 = u1 + u1
      cap_ext = params[:cap_ext] || u1
      pcont_dy = params[:pcont_dy] || 0
      offset = vs+ u2+u1/2+u1/8
      create_box indices[:m1], 0, 0, offset + cw + cap_ext, cl
      create_box indices[:cap], offset, 0, offset + cw, cl
      if polcnt_outside
        create_box indices[:pol], offset, -cap_ext, offset + cw , cl+u2+vs + pcont_dy
        create_contacts_horizontally indices, offset,  offset + cw, cl + vs/2 + u1 + pcont_dy, vs, u1, params[:hpitch]
      else
        create_box indices[:pol], offset, -cap_ext, offset + cw , cl-u2-vs + pcont_dy
        create_contacts_horizontally indices, offset,  offset + cw, cl - vs/2 - u1 + pcont_dy, vs, u1, params[:hpitch]
      end
    end
  end

  class MinedaSlit_cap < MinedaCapacitor
    # include MinedaPCell
    def display_text_impl
      "Slit capacitor\r\n(L=#{(us*nc).to_s}um,W=#{(us*nr).to_s}um, C=#{cval.to_s}"
    end
    def draw_unit index, x, y, u
      create_box index, x-u/2, y-u/2, x+u/2, y+u/2
    end
    def produce_impl(indices, vs, u1, usize, nc, nr, slit_length, slit_width, csq)
      (0..(hp ? nc: nc-1)).each{|i|
        (0..nr-1).each{|j|
          puts [i, j].inspect
          x = i*usize + (hp ? 0 : usize/2)
          y = j*usize + usize/2
          draw_unit(indices[:m1], x, y, usize -  slit_width)
          draw_unit(indices[:m1], x - usize/2 + csq/2, y - usize/2 + csq/2, csq)
          draw_unit(indices[:m1], x + usize/2 - csq/2, y - usize/2 + csq/2, csq)
          draw_unit(indices[:m1], x - usize/2 + csq/2, y + usize/2 - csq/2, csq)
          draw_unit(indices[:m1], x + usize/2 - csq/2, y + usize/2 - csq/2, csq)
        }
      }
      us2 = usize/2
      if hp # high precision
         create_box indices[:m1], -us2,  0, nc*usize + us2, slit_width
         create_box indices[:m1], -us2,  nr*usize, nc*usize + us2, nr*usize - slit_width
         create_box indices[:pol], 0, -us2, nc*usize, nr*usize + us2
         create_box indices[:m1], -us2, 0, -us2 + slit_width, nr*usize
         create_box indices[:m1], nc*usize + us2, 0, nc*usize + us2 - slit_width, nr*usize
         create_box indices[:cap], 0, 0, nc*usize, nr*usize
      else
        create_box indices[:pol], 0, 0, nc*usize, nr*usize
        create_box indices[:cap], slit_width, slit_width, nc*usize-slit_width, nr*usize-slit_width
      end
    end
  end

  class MinedaFinger_cap < MinedaCapacitor
    # include MinedaPCell
    def display_text_impl
      "Finger capacitor\r\n(L=#{fl.round(3)}um,W=#{(fw*nf + fg*(nf-1)).round(3)}um, C=#{cval.to_s}"
    end
    def draw_fingers index, fl, fw, fg, nf, flag
      pitch = (fw + fg)*2
      y = 0
      for i in 0..((nf+1)/2).to_i - 1 do
        x = flag ? -fg-fw/2 : fl+fg+fw/2
        if y > 0
          points = [Point::new(x, y), Point::new(x, y - pitch)]
          cell.shapes(index).insert(Path::new(points, fw, fw/2, fw/2))
        end
        points = flag ? [Point::new(x, y), Point::new(fl, y)] : [Point::new(0, y), Point::new(x, y)]
        cell.shapes(index).insert(Path::new(points, fw, 0, 0))
        y = y + pitch
      end
      y = fw + fg
      x = nil
      for i in ((nf+1)/2).to_i..(nf-1) do
        x = flag ? fl+fg+fw/2 : -fg-fw/2
        if y > fw + fg
          points = [Point::new(x, y), Point::new(x, y - pitch)]
          cell.shapes(index).insert(Path::new(points, fw, fw/2, fw/2))
        end
        points = flag ? [Point::new(0, y), Point::new(x, y)] : [Point::new(x, y), Point::new(fl, y)]
        cell.shapes(index).insert(Path::new(points, fw, 0, 0))
        y = y + pitch
      end
      [x, fw + fg, y - pitch]
    end
    def produce_impl(indices, vs, u1, finger_length, finger_width, finger_gap, nf)
      # super indices, vs, u1, finger_length, finger_width, finger_gap, nf
      x0, y0, y1 = draw_fingers indices[:m2], finger_length, finger_width, finger_gap, nf, true
      create_contacts_vertically indices, x0, y0, y1, vs, u1
      x1, y0, y1 = draw_fingers indices[:m3], finger_length, finger_width, finger_gap, nf, false
      create_contacts_vertically indices, x1, y0, y1, vs, u1
      create_box indices[:cap], 0, -finger_width/2, finger_length, finger_width*nf + finger_gap*(nf-1) - finger_width/2
    end
  end
end
##############################################################################################
