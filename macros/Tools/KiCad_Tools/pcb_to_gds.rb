# coding: utf-8
require 'sxp'

module PCB_to_gds
  include RBA
  include MinedaPCellCommonModule

  # 1. モジュール関数として定義する（self. をつける）
  def self.rot_to_am(rotation)
    case rotation
    when 'R0'   then [0, false]
    when 'R90'  then [1, false]
    when 'R180' then [2, false]
    when 'R270' then [3, false]
    when 'M0'   then [0, true]
    when 'M45'  then [1, true]
    when 'M90'  then [2, true]
    when 'M135' then [3, true]
    else             [0, false]
    end
  end
  
  # メソッドの中に処理を閉じ込める（GC対策）
  def self.run
    mw = Application.instance.main_window
    view = mw.current_view&.active_cellview
    
    if view
      pcb_file = QFileDialog::getOpenFileName(mw, 'KiCad PCB file', File.dirname(view.filename), 'pcb(*.kicad_pcb)')
      return if pcb_file.empty? # キャンセル対策
      layout = view.layout
      
      # top_cellをクリアするのではなく、新しく作り直して古いセルを安全に捨てる
      top_cell = layout.cell("TOP") || layout.create_cell("TOP")
      top_cell.clear 
    else
      # ※gds_fileが未定義だったので ENV['HOME'] 等から仮に生成
      home_dir = ENV['HOME'] || ENV['HOMEPATH']
      pcb_file = QFileDialog::getOpenFileName(mw, 'KiCad PCB file', home_dir, 'pcb(*.kicad_pcb)')
      return if pcb_file.empty?
      layout = Layout.new
      layout.dbu = 0.001
      top_cell = layout.create_cell("TOP")
    end
    
    puts "*** pcb_file #{pcb_file} to GDS conversion started"
    
    # 完全にインクルードされたモジュールからインスタンス作成
    mpc = MinedaPCellCommon.new
    mpc.set_technology(view ? view.technology : "")
    mpc.set_layer_index
    
    dbu = layout.dbu
    layers = {}
    
    # レイヤー取得時に例外やnilを考慮
    begin
      layers["F.Cu"] = layout.layer(mpc.get_layer_index('ML1', false), 0)
      layers["B.Cu"] = layout.layer(mpc.get_layer_index('ML2', false), 0)
      layers["Via"]  = layout.layer(mpc.get_layer_index('VIA1', false), 0)
    rescue => e
      puts "Layer setup error: #{e.message}"
      return
    end

    library = Library.library_by_name("PCells")
    raise "Library 'PCells' not found" unless library

    kpcb = SXP.read(File.read(pcb_file).encode('UTF-8'))
    raw_segments = []
    kpcb[1..-1].each do |blk|
      if blk[0] == :footprint
        blk[1] =~ /^(\S+):(\S+)\.l(\S+)w(\S+)m(\S+)_(\S+)/
        lib, sym, l, w, m, rot = [$1, $2, $3.to_f, $4.to_f, $5.to_i, $6]
        
        decl = library.layout.pcell_declaration(sym)
        next unless decl # PCellが見つからない場合のスキップ処理
        
        pcell_id = layout.add_pcell_variant(library, decl.id, { "w" => w, "l" => l, "n" => m })
        at = blk.assoc(:at)
        ref = nil
        
        blk[4..-1].each do |item|
          if item[0] == :property && item[1] == 'Reference'
            ref = item[2]
            break
          end
        end 
        
        x, y = [at[1], at[2]].map(&:to_f)
        angle, mirror = rot_to_am(rot)
        
        fp_trans = Trans.new(angle, mirror, (x/dbu).to_i, (-y/dbu).to_i)
        top_cell.insert(CellInstArray.new(pcell_id, fp_trans))
=begin        
      elsif blk[0] == :segment
        start = blk.assoc(:start)[1..2].map(&:to_f)
        end_ = blk.assoc(:end)[1..2].map(&:to_f) 
        width = blk.assoc(:width)[1].to_f # to_f に修正（DBU計算のため）
        layer = blk.assoc(:layer)[1]
        
        # 【重要】レイヤーの存在チェック（nil落ち対策）
        target_layer = layers[layer]
        if target_layer
          p1 = Point.new((start[0]/dbu).to_i, (-start[1]/dbu).to_i)
          p2 = Point.new((end_[0]/dbu).to_i, (-end_[1]/dbu).to_i)
          path = Path.new([p1, p2], (width/dbu).to_i)     
          top_cell.shapes(target_layer).insert(path)
        else
          # 未定義レイヤー（Edge.Cutsなど）は安全に無視する
          puts "Skipping unsupported layer: #{layer}"
        end
      end
    end
=end    
      elsif blk[0] == :segment
        # 直接 shapes に入れず、一旦メモリ上の配列にストックする
        # (あらかじめループの前に `raw_segments = []` などの初期化を入れておいてください)
        start = blk.assoc(:start)[1..2].map(&:to_f)
        end_ = blk.assoc(:end)[1..2].map(&:to_f) 
        width = blk.assoc(:width)[1].to_f
        layer = blk.assoc(:layer)[1]
        
        raw_segments << { start: start, end: end_, width: width, layer: layer }
      end
    end # ここで kpcb のループ終了
    
    # ==========================================================
    # 【追加】ストックしたセグメントを連結して一本のPathとして描画する処理
    # ==========================================================
    # レイヤーと幅（width）ごとにグループ化
    grouped_segments = raw_segments.group_by { |s| [s[:layer], s[:width]] }
    
    grouped_segments.each do |(layer, width), segs|
      target_layer = layers[layer]
      next unless target_layer # 安全対策のレイヤーチェック
      
      # 繋がっているセグメントを一本の「点の配列」に連結する
      paths_points = []
      
      until segs.empty?
        current = segs.shift
        # KLayoutの整数座標（DBU単位）に変換して開始点・終了点を定義
        p_start = Point.new((current[:start][0]/dbu).to_i, (-current[:start][1]/dbu).to_i)
        p_end   = Point.new((current[:end][0]/dbu).to_i, (-current[:end][1]/dbu).to_i)
        
        current_path = [p_start, p_end]
        
        # 前後に繋がるセグメントが残りのリストにあれば、貪欲に結合していく
        loop do
          found = false
          segs.each_with_index do |s, idx|
            s_start = Point.new((s[:start][0]/dbu).to_i, (-s[:start][1]/dbu).to_i)
            s_end   = Point.new((s[:end][0]/dbu).to_i, (-s[:end][1]/dbu).to_i)
            
            if current_path.last == s_start
              current_path << s_end
              segs.delete_at(idx)
              found = true
              break
            elsif current_path.last == s_end
              current_path << s_start
              segs.delete_at(idx)
              found = true
              break
            elsif current_path.first == s_end
              current_path.unshift(s_start)
              segs.delete_at(idx)
              found = true
              break
            elsif current_path.first == s_start
              current_path.unshift(s_end)
              segs.delete_at(idx)
              found = true
              break
            end
          end
          break unless found
        end
        paths_points << current_path
      end
=begin     
      # 連結が完了した座標列から、KLayoutのPathを生成して流し込む
      paths_points.each do |pts|
        # 隣り合う重複した点を削除してきれいに整形
        pts.uniq!
        next if pts.size < 2 # 点が2個未満（線にならない）ならスキップ
        
        path = Path.new(pts, (width/dbu).to_i)
        top_cell.shapes(target_layer).insert(path)
      end   
=end
      # 連結が完了した座標列から、KLayoutのPathを生成して流し込む
      paths_points.each do |pts|
        pts.uniq!
        next if pts.size < 2
=begin        
        # ==========================================================
        # 【追加】45度（斜め）配線を垂直・水平（直角）に変換する処理
        # ==========================================================
        manhattan_pts = [pts.first]
        
        (0...(pts.size - 1)).each do |i|
          p1 = pts[i]
          p2 = pts[i + 1]
          
          # X座標もY座標も異なる（＝斜め配線である）場合
          if p1.x != p2.x && p1.y != p2.y
            # 直角に曲げるための中継点を作成（水平に進んでから垂直に曲がるパターン）
            # ※もし逆方向（垂直→水平）に曲げたい場合は Point.new(p1.x, p2.y) に変更してください
            mid_point = Point.new(p2.x, p1.y)
            
            manhattan_pts << mid_point
          end
          manhattan_pts << p2
        end
=end 
        # ==========================================================
        # 【改良】微小なブレを平滑化し、すっきりとした直角配線にする処理
        # ==========================================================
        # 1. まず近すぎる不要な点（微小な段差の原因）を除去して単純化する
        simplified_pts = [pts.first]
        threshold = (width / dbu).to_i / 2 # 配線幅の半分未満のブレは無視する閾値
        
        (1...(pts.size)).each do |i|
          last_p = simplified_pts.last
          curr_p = pts[i]
          
          # 前の点からの移動距離が閾値より大きい場合のみ、重要な頂点として残す
          # (ただし最後の端点だけは必ず残す)
          if (curr_p.x - last_p.x).abs > threshold || (curr_p.y - last_p.y).abs > threshold || i == pts.size - 1
            simplified_pts << curr_p
          end
        end
        
        # 2. 単純化した頂点（simplified_pts）を使って直角化を行う
        manhattan_pts = [simplified_pts.first]
        
        (0...(simplified_pts.size - 1)).each do |i|
          p1 = simplified_pts[i]
          p2 = simplified_pts[i + 1]
          
          # 斜め配線のみを直角に補正
          if p1.x != p2.x && p1.y != p2.y
            # 閾値より小さなブレは完全に吸収して水平・垂直に揃える
            if (p1.x - p2.x).abs < threshold
              mid_point = Point.new(p1.x, p2.y)
            elsif (p1.y - p2.y).abs < threshold
              mid_point = Point.new(p2.x, p1.y)
            else
              # 通常の斜めは水平に進んでから垂直に曲げる
              mid_point = Point.new(p2.x, p1.y)
            end
            manhattan_pts << mid_point
          end
          manhattan_pts << p2
        end       
        manhattan_pts.uniq! # 重複した中継点を削除
        # ==========================================================
        
        # 修正された直角座標列（manhattan_pts）を使ってPathを生成
        path = Path.new(manhattan_pts, (width/dbu).to_i)
        top_cell.shapes(target_layer).insert(path)
      end
    end
    if mw.current_view
      mw.current_view.zoom_fit
    end
  end
end

# スクリプト実行
PCB_to_gds.run
