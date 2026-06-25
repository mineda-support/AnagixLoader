
# Enter your Ruby code here

# coding: cp932
module MyBatchGenerator
  include RBA
  unless MainWindow.instance
    load '~/KLayout/salt/AnagixLoader/macros/MinedaCommon.rb'
    load '~/KLayout/salt/AnagixLoader/macros/MinedaPCell.rb'

    tech_lyt_path = File.join(ENV['HOMEPATH']||ENV['HOME'],'KLayout/salt/PTS06/Technology/tech/tech.lyt')
    tech = Technology.new
    tech.load(tech_lyt_path)
    Technology.remove_technology('PTS06') if Technology.technology_names.include?('PTS06')
    Technology.register_technology(tech)
    require 'rexml/document'
    lym_path= File.join(ENV['HOMEPATH']||ENV['HOME'],'KLayout/salt/PTS06/Technology/tech/macros/pcell_v0.1.lym')
    doc = REXML::Document.new(File.read(lym_path))
  # <text> タグの中にあるRubyコードを取得
    ruby_code = doc.elements["//text"].text
  # 取得したコードを現在のコンテキストで実行し、PCellを登録
    eval(ruby_code)
  end
  
  def self.run
    # 1. 新しいレイアウトを生成
    layout = Layout.new
    layout.dbu = 0.001 # データベースユニットを1nmに設定
    
    # トップセルの作成
    top_cell = layout.create_cell("TOP")
    
    # 2. カスタムPCellライブラリの取得
    # （'MyCustomLib' と 'MyDevicePCell' を実際の名称に書き換えてください）
    lib_name = "PCells_PTS06"
    pcell_name = "Pch"
    
    lib = Library.library_by_name(lib_name)
    if lib.nil?
      puts "エラー: ライブラリ '#{lib_name}' が見つかりません。パスを確認してください。"
      return
    end
    
    # PCellの宣言（定義）を取得
    pcell_decl = lib.layout.pcell_declaration(pcell_name)
    
    # 3. PCellに渡すパラメータを設定
    # ※ハッシュのキーはPCell側で定義した「パラメータ名」に合わせます

    pcell_params = {
      "w"  => 3.6.um,
      "l" => 0.6.um,
#      "layer"  => LayerInfo.new(1, 0) # 必要に応じてLayerInfoオブジェクトを渡す
    }

    # 4. パラメータを適用したPCellのバリアントをレイアウト内に生成
    pcell_variant_id = layout.add_pcell_variant(lib, pcell_decl.id, pcell_params)
    
    # 5. 生成したPCellインスタンスをトップセルに配置
    # 原点(0,0)、回転なしの座標変換
    transformation = Trans.new(Point.new(0, 0))
    top_cell.insert(CellInstArray.new(pcell_variant_id, transformation))
    
    # 6. GDSファイルとして書き出し
    output_gds = "generated_devices.gds"
    layout.write(output_gds)
    puts "成功: バッチ生成が完了し、#{output_gds} に保存されました。"

    if MainWindow.instance
      # 1. 新しいビュー（タブ）を作成する
      MainWindow.instance.create_view()
  
      # 2. 現在アクティブになった（今作った）LayoutView オブジェクトを取得する
      view = MainWindow.instance.current_view()
  
      # 3. 保存したGDSファイルを安全に読み込む
      view.load_layout(output_gds, false)
    end
    
    # --- 2. KiCadフットプリントの生成処理（拡張部分） ---
    footprint_name = pcell_name # "MyGeneratedDevice"
    
    # 【変更案A】分かりやすくユーザーフォルダ直下の特定の場所に固定する場合
    output_dir = File.join(ENV['HOMEPATH']||ENV['HOME'], "Seafile/KiCad4LSI/MyCustomLibrary.pretty")
    
    # 【変更案B】デスクトップに直接出したい場合
    # output_dir = File.join(ENV['HOMEPATH'], "Desktop/MyCustomLibrary.pretty")

    # Windowsのバックスラッシュ（\）をスラッシュ（/）に統一
    output_dir = output_dir.gsub('\\', '/')
    
    # ライブラリフォルダが存在しない場合は作成
    Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
    
    # 出力ファイルパス
    kicad_mod_path = File.join(output_dir, "#{footprint_name}.kicad_mod")
    # S式（S-expression）テキストの構築
    # ※ KiCad v6 / v7 / v8 形式に準拠
    s_expr =  "(footprint \"#{footprint_name}\"\n"
    s_expr += "  (version 20240101)\n"
    s_expr += "  (generator \"KLayout_Ruby_Script\")\n"
    s_expr += "  (layer \"F.Cu\")\n"
    s_expr += "  (descr \"Generated automatically from KLayout PCell\")\n"
    
    # デフォルトの参照符号（Reference）と値（Value）のテキスト配置
    s_expr += "  (fp_text reference \"REF**\" (at 0 -5) (layer \"F.SilkS\") (effects (font (size 1 1) (thickness 0.15))))\n"
    s_expr += "  (fp_text value \"#{footprint_name}\" (at 0 1) (layer \"F.Fab\") (effects (font (size 1 1) (thickness 0.15))))\n"

    # ================================================================
    # 【本当の最終確定版】左右条件の適用 ＋ ゲート消失バグの完全修正
    # ================================================================
    flat_cell = layout.create_cell("TEMP_FLAT_CELL")
    flat_cell.insert(CellInstArray.new(pcell_variant_id, Trans.new(Point.new(0,0))))
    flat_cell.flatten(true)

    # flat_cellのコンテキストでレイヤーIDを安全に再取得
    layer_ml1_scan = flat_cell.layout.layer(LayerInfo.new(6, 0))  # ML1
    layer_ml2      = flat_cell.layout.layer(LayerInfo.new(9, 0))  # ML2
    layer_via1     = flat_cell.layout.layer(LayerInfo.new(8, 0))  # VIA1
    layer_pol      = flat_cell.layout.layer(LayerInfo.new(4, 0))  # POL
    layer_diff     = flat_cell.layout.layer(LayerInfo.new(20, 0)) # DIFF

    # 1. 金属層(ML1)だけの極限座標を測定
    kicad_x_coords = []
    kicad_y_coords = []
    flat_cell.each_shape(layer_ml1_scan) do |shape|
      kicad_x_coords << (shape.bbox.center.x * layout.dbu).round(4)
      kicad_y_coords << -(shape.bbox.center.y * layout.dbu).round(4) # KiCadの上下反転座標
    end

    if kicad_x_coords.any?
      min_x, max_x = kicad_x_coords.min, kicad_x_coords.max
      min_y, max_y = kicad_y_coords.min, kicad_y_coords.max
    else
      min_x, max_x, min_y, max_y = 0.0, 10.0, -10.0, 0.0
    end
    
    mid_x = (min_x + max_x) / 2.0

    # 2. 左右と上下の四隅を厳密に100%特定するラムダ式
    find_pin_num = lambda do |cx, cy|
      is_left = cx < mid_x

      # 本当の極限の端っこ（0.2um以内）だけを端子エリアにする
      is_top_edge    = (cy - min_y).abs < 0.2
      is_bottom_edge = (max_y - cy).abs < 0.2

      if pcell_name.to_s.include?("Pch")
        # ==========================================
        # 🔴 Pch用の四隅絶対ルール (DGSB完全準拠版)
        # ==========================================
        if is_top_edge
          return is_left ? "3" : "4" # 左上=ソース(3)、右上=バルク(4)
        elsif is_bottom_edge
          return is_left ? "2" : "1" # 左下=ゲート(2)、右下=ドレイン(1)
        else
          return is_left ? "3" : "1" # 左側中央=ソース(3)、右側中央=ドレイン(1)
        end
      else
        # ==========================================
        # 🔵 Nch用の四隅絶対ルール (DGSB完全準拠版)
        # ==========================================
        if is_top_edge
          return is_left ? "2" : "1" # 左上=ゲート(2)、右上=ドレイン(1)
        elsif is_bottom_edge
          return is_left ? "3" : "4" # 左下=ソース(3)、右下=バルク(4)
        else
          return is_left ? "3" : "1" # 左側中央=ソース(3)、右側中央=ドレイン(1)
        end
      end
    end


    # --- ① ML1 (6/0) -> 表面銅箔パッド (F.Cu) ---
    flat_cell.each_shape(layer_ml1_scan) do |shape|
      bbox = shape.bbox
      w = (bbox.width * layout.dbu).round(4)
      h = (bbox.height * layout.dbu).round(4)
      cx = (bbox.center.x * layout.dbu).round(4)
      cy = -(bbox.center.y * layout.dbu).round(4)
      
      pin_num = find_pin_num.call(cx, cy)
      s_expr += "  (pad \"#{pin_num}\" smd rect (at #{cx} #{cy}) (size #{w} #{h}) (layers \"F.Cu\" \"F.Paste\" \"F.Mask\"))\n"
    end

    # --- ② ML2 (9/0) -> 裏面銅箔パッド (B.Cu) ---
    flat_cell.each_shape(layer_ml2) do |shape|
      bbox = shape.bbox
      w = (bbox.width * layout.dbu).round(4)
      h = (bbox.height * layout.dbu).round(4)
      cx = (bbox.center.x * layout.dbu).round(4)
      cy = -(bbox.center.y * layout.dbu).round(4)
      
      pin_num = find_pin_num.call(cx, cy)
      s_expr += "  (pad \"#{pin_num}\" smd rect (at #{cx} #{cy}) (size #{w} #{h}) (layers \"B.Cu\" \"B.Mask\"))\n"
    end

    # --- ③ VIA1 (8/0) -> スルーホール (Through-hole) ---
    flat_cell.each_shape(layer_via1) do |shape|
      bbox = shape.bbox
      via_w = (bbox.width * layout.dbu).round(4)
      via_h = (bbox.height * layout.dbu).round(4)
      cx = (bbox.center.x * layout.dbu).round(4)
      cy = -(bbox.center.y * layout.dbu).round(4)
      
      size_dia = [via_w, via_h].max
      drill_dia = (size_dia * 0.6).round(4)
      
      pin_num = find_pin_num.call(cx, cy)
      s_expr += "  (pad \"#{pin_num}\" thru_hole circle (at #{cx} #{cy}) (size #{size_dia} #{size_dia}) (drill #{drill_dia}) (layers \"*.Cu\" \"*.Mask\"))\n"
    end

    # --- ④ POL (4/0) -> ゲート形状を完璧に描き出す ---
    flat_cell.each_shape(layer_pol) do |shape|
      bbox = shape.bbox
      w = (bbox.width * layout.dbu).round(4)
      h = (bbox.height * layout.dbu).round(4)
      
      # 💡【最重要修正】Wが3倍になって大きくなったゲートPOLが消えないよう、制限を15.0μmに拡大
      next if w > 15.0 || h > 15.0 
      
      cx = (bbox.center.x * layout.dbu).round(4)
      cy = -(bbox.center.y * layout.dbu).round(4)
      
      x1, x2 = (cx - w/2.0).round(4), (cx + w/2.0).round(4)
      y1, y2 = (cy - h/2.0).round(4), (cy + h/2.0).round(4)
      
      s_expr += "  (fp_poly (pts (xy #{x1} #{y1}) (xy #{x2} #{y1}) (xy #{x2} #{y2}) (xy #{x1} #{y2})) (stroke (width 0.05) (type solid)) (fill solid) (layer \"F.Fab\"))\n"
    end

    # --- ⑤ DIFF (20/0：拡散層) -> アクティブ領域をシルク破線で囲む ---
    flat_cell.each_shape(layer_diff) do |shape|
      bbox = shape.bbox
      w = (bbox.width * layout.dbu).round(4)
      h = (bbox.height * layout.dbu).round(4)
      next if w > 15.0 || h > 15.0
      
      cx = (bbox.center.x * layout.dbu).round(4)
      cy = -(bbox.center.y * layout.dbu).round(4)
      
      x1, x2 = (cx - w/2.0).round(4), (cx + w/2.0).round(4)
      y1, y2 = (cy - h/2.0).round(4), (cy + h/2.0).round(4)
      
      silk = (pcell_name == 'Nch') ? 'F.SilkS' : 'B.SilkS'
      s_expr += "  (fp_poly (pts (xy #{x1} #{y1}) (xy #{x2} #{y1}) (xy #{x2} #{y2}) (xy #{x1} #{y2})) (stroke (width 0.05) (type dash)) (fill none) (layer \"#{silk}\"))\n"
    end

    flat_cell.destroy
    
    s_expr += ")\n"
    
    # ファイルへの書き出し
    File.open(kicad_mod_path, "w") do |f|
      f.write(s_expr)
    end
    
    puts "成功: KiCadフットプリントを保存しました -> #{kicad_mod_path}"
  end
end

MyBatchGenerator.run
