# frozen_string_literal: true

# 現代日本語 → 白文 → 訓点 の通し確認（Ollama と MeCab が動いている環境で実行する）。
#
#   bin/rails runner script/translate_bench.rb              … 内蔵の 10 文で測る
#   bin/rails runner script/translate_bench.rb 文例.txt      … ファイルの各行を測る（空行は無視）
#   bin/rails runner script/translate_bench.rb script/bench_expected.tsv
#       … 原文<TAB>期待白文（TAB 区切りで複数可）。意味が合っているかも測る（Phase 4n）
#
# 見るもの
#   白文率   … LLM の出力が漢字と句読点だけか（プロンプトの効き）
#   解析率   … Racc パーサーが返り点まで付けられたか（辞書と文法の範囲）
#   再試行   … 仮名混じりで 1 回作り直した件数
#   一致率   … （.tsv のとき）白文が期待白文のどれかと一致した率
#   完全成功 … 解析も一致も成り立った率。通ったが意味違い＝「解析OK・不一致」は別に数える
#   辞書にない字 … parse_error に出た字の頻度（Lexicon に足す候補）

DEFAULT_SENTENCES = %w[
  私は林檎を食べる 学ぶことは楽しい 知らないことは恥ではない 花が咲き鳥が鳴く
  山は高く水は清い 酒を飲んで山に登る 月が出て夜が明ける 人は皆死ぬ
  私は漢文を読まない 春の夜は短い
].freeze

expected = {}
sentences =
  if ARGV[0].to_s.end_with?(".tsv")
    File.readlines(ARGV[0], chomp: true).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }.map do |line|
      text, *answers = line.split("\t").map(&:strip)
      expected[text] = answers
      text
    end
  elsif ARGV[0]
    File.readlines(ARGV[0], chomp: true).map(&:strip).reject(&:empty?)
  else
    DEFAULT_SENTENCES
  end

rows = sentences.map do |text|
  result = KanbunTranslatorService.call(text)
  { text: text, result: result }
end

rows.each do |row|
  r = row[:result]
  mark = r.parse_error.nil? ? "OK " : "-- "
  match = expected.empty? ? "" : (expected[row[:text]].to_a.include?(r.hakubun) ? "= " : "≠ ")
  puts "#{mark}#{match}#{row[:text]} | #{r.hakubun} | #{r.kunten}#{r.retried ? ' | 再試行' : ''}"
  puts "     #{r.parse_error}" if r.parse_error
  puts "     期待: #{expected[row[:text]].join(' / ')}" if !match.empty? && match.start_with?("≠")
end

total = rows.size
pure = rows.count { |row| row[:result].hakubun.to_s.match?(KanbunTranslatorService::HAKUBUN_PATTERN) }
parsed = rows.count { |row| row[:result].parse_error.nil? }
retried = rows.count { |row| row[:result].retried }

unless expected.empty?
  matched = rows.count { |row| expected[row[:text]].to_a.include?(row[:result].hakubun) }
  both = rows.count { |row| row[:result].parse_error.nil? && expected[row[:text]].to_a.include?(row[:result].hakubun) }
  wrong_meaning = rows.count { |row| row[:result].parse_error.nil? && !expected[row[:text]].to_a.include?(row[:result].hakubun) }
end

unknown = Hash.new(0)
rows.each do |row|
  err = row[:result].parse_error.to_s
  next unless err.start_with?("UnknownCharacters")

  err.split(": ").last.each_char { |c| unknown[c] += 1 }
end

puts
puts "白文率 #{pure}/#{total}　解析率 #{parsed}/#{total}　再試行 #{retried}"
puts "一致率 #{matched}/#{total}　完全成功 #{both}/#{total}　解析OKだが不一致 #{wrong_meaning}" unless expected.empty?
unless unknown.empty?
  ranking = unknown.sort_by { |c, n| [-n, c] }.map { |c, n| "#{c}×#{n}" }.join(" ")
  puts "辞書にない字: #{ranking}"
end
