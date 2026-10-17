# frozen_string_literal: true

# 返り点つき白文の表（TSV）を読み、パーサー＋Kunten の出力が表の返り点と一致するかを確かめる。
#   ruby script/kunten_check.rb /path/to/table.tsv
# TSV は 1 行 1 文、タブ区切りで 1 列目が「返り点つき白文」（例: 空山不[レ]見[レ]人）。2 列目以降は無視する。
# 学習書の例文は著作物なので、表自体はリポジトリに入れず、手元に置いて使う。

require_relative '../lib/kanbun/kanbun_parser.tab'
require_relative '../lib/kanbun/kunten'

path = ARGV.fetch(0) { abort 'usage: ruby script/kunten_check.rb TABLE.tsv' }
ok = 0
total = 0
File.readlines(path, chomp: true, encoding: 'UTF-8').each do |line|
  next if line.empty? || line.start_with?('#')

  expected = line.split("\t").first
  hakubun = expected.gsub(/\[[^\]]*\]/, '')
  total += 1
  begin
    units = Kanbun::Kunten.annotate(KanbunParser.new.parse_tree(hakubun, strict: true))
    got = Kanbun::Kunten.to_bracket(units)
    if got == expected
      ok += 1
      puts "OK   #{expected}"
    else
      puts "DIFF #{expected}  出力: #{got}"
    end
  rescue StandardError => e
    puts "--   #{expected}  #{e.class.name.split('::').last}: #{e.message[0, 50]}"
  end
end
puts "一致 #{ok}/#{total}"
