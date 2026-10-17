# frozen_string_literal: true

# 注記つき漢文から白文・書き下し文を表示するデモ。
#   ruby script/demo.rb              … テストデータ（spec/support/kanbun_fixtures.rb）を全件表示
#   ruby script/demo.rb 入力.txt      … ファイルの各行を変換（空行・# で始まる行は無視）
#   echo '…' | ruby script/demo.rb -  … 標準入力の各行を変換
# LANG=C.UTF-8 推奨。

require_relative '../spec/support/kanbun_fixtures'
require_relative '../lib/kanbun/kakikudashi'

def show(title, text)
  puts "■ #{title}"
  puts "  正本    : #{text}"
  puts "  白文    : #{Kanbun::Aozora.hakubun(text)}"
  puts "  書き下し: #{Kanbun::Kakikudashi.convert(text, yomi: true)}"
  puts "  平仮名  : #{Kanbun::Kakikudashi.convert(text, yomi: false, hiragana: true)}"
  puts
rescue Kanbun::Aozora::ParseError, Kanbun::Reorder::Error => e
  puts "  エラー  : #{e.message}\n\n"
end

if ARGV.empty?
  KanbunFixtures::CASES.each { |c| show(c[:name], c[:text]) }
else
  lines = ARGV[0] == '-' ? $stdin.read.lines : File.readlines(ARGV[0], chomp: true)
  lines.map(&:strip).reject { |l| l.empty? || l.start_with?('#') }.each_with_index do |l, i|
    show("入力#{i + 1}", l)
  end
end
