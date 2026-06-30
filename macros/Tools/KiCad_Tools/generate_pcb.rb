# coding: utf-8
require 'yaml'
require 'securerandom'
Dir.chdir '/home/anagix/Seafile/KiCad4LSI/Test4.pretty'

# --- 設定変数 ---
YAML_FILE = 'op8_22_v2.yaml'       # 入力するYAMLファイル名
OUTPUT_PCB = '../op8_22_v2.kicad_pcb'    # 出力するKiCad PCBファイル名
LIB_NAME = 'Test4'             # KiCad上でのライブラリ識別子（任意）
PRETTY_DIR = '.'
# ----------------
TARGET_CENTER_X = 150.0  # A4枠(297x210)のほぼ中央
TARGET_CENTER_Y = 100.0  # A4枠(297x210)のほぼ中央
SCALE = 200.0

# ランダムなUUID（path）を生成するヘルパー
def generate_uuid
  SecureRandom.uuid
end

# フットプリントファイル(.kicad_mod)から中身（形状部分）を抽出する関数
def get_footprint_body(fp_name)
  mod_path = File.join(PRETTY_DIR, "#{fp_name}.kicad_mod")
  return "" unless File.exist?(mod_path)

  lines = File.readlines(mod_path)
  # 最初の行 (footprint ...) と最後の行 ) を除いた、中身の行だけを結合する
  body_lines = lines[1...-1]
  body_lines ? body_lines.join : ""
end

# 基板データの最小構成テンプレート（KiCad v6/v7/v8 互換形式）
pcb_template_header = <<~PCB
(kicad_pcb (version 20211014) (generator pcbnew)
  (general
    (thickness 1.6)
  )
  (paper "A4")
  (layers
    (0 "F.Cu" signal)
    (31 "B.Cu" signal)
    (32 "B.Adhes" user "B.Adhesive")
    (33 "F.Adhes" user "F.Adhesive")
    (34 "B.Paste" user)
    (35 "F.Paste" user)
    (36 "B.SilkS" user "B.Silkscreen")
    (37 "F.SilkS" user "F.Silkscreen")
    (38 "B.Mask" user)
    (39 "F.Mask" user)
    (40 "Dwgs.User" user)
    (41 "Cmts.User" user)
    (42 "Eco1.User" user)
    (43 "Eco2.User" user)
    (44 "Edge.Cuts" user)
    (45 "Margin" user)
    (46 "B.CrtYd" user "B.Courtyard")
    (47 "F.CrtYd" user "F.Courtyard")
    (48 "B.Fab" user)
    (49 "F.Fab" user)
  )
PCB

# YAMLの読み込み
unless File.exist?(YAML_FILE)
  puts "エラー: YAMLファイル '#{YAML_FILE}' が見つかりません。"
  exit 1
end

placement_data = YAML.load_file(YAML_FILE)

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
  pos_x = (x * SCALE) + offset_x
  pos_y = (y * SCALE) + offset_y

  uuid = generate_uuid
  
  fp_body = get_footprint_body(fp_name)

  footprints_sexpr << "  (footprint \"#{LIB_NAME}:#{fp_name}\" (at #{pos_x} #{pos_y}) (layer \"F.Cu\")\n"
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

# ファイル書き出し
File.open(OUTPUT_PCB, 'w') do |file|
  file.write(pcb_template_header)
  file.write(footprints_sexpr)
  #file.write(pcb_template_footer)
  file.write(")\n")
end

puts "成功: '#{OUTPUT_PCB}' を生成しました（合計 #{placement_data.size} 個の素子）。"
