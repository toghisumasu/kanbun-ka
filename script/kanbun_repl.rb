# frozen_string_literal: true

# 現代日本語を 1 行ずつ入力して、漢文白文・返り点・書き下しを見る対話ツール。
#
#   bin/rails runner script/kanbun_repl.rb
#
# 空行・exit・quit・Ctrl-D で終了。Ollama と MeCab が動いている環境で実行する。

require "readline"

puts "現代日本語を入力してください（空行か exit で終了）"

while (line = Readline.readline("日本語> ", true))
  text = line.strip
  break if text.empty? || %w[exit quit].include?(text)

  begin
    r = KanbunTranslatorService.call(text)
    puts "  骨格    : #{r.skeleton.inspect}"
    puts "  白文    : #{r.hakubun}#{r.retried ? '（再試行）' : ''}"
    if r.parse_error
      puts "  訓点    : （解析できません）#{r.parse_error}"
    else
      puts "  返り点  : #{r.kunten}"
      puts "  書き下し: #{r.kakikudashi}"
    end
  rescue StandardError => e
    puts "  エラー  : #{e.class}: #{e.message}"
  end
  puts
end
