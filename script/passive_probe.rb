# frozen_string_literal: true

# 受身の規則（プロンプト）の効きを、同じ文を複数回流して見る（Phase 5b S9）。LLM の出力は揺れるので回数で見る。
# Ollama と MeCab が動いている環境で実行する。
#
#   bin/rails runner script/passive_probe.rb                      … 受身 8 文＋対照 4 文を 3 回ずつ
#   RUNS=2 bin/rails runner script/passive_probe.rb script/bench_expected.tsv
#                                                                  … ベンチを RUNS 回ずつ（期待白文との一致も数える）
#
# 出力：文ごとに 回ごとの［骨格｜白文｜exact｜reasons］と、集計（被 が出た回／exact の回／期待一致の回）。
# exact は、LLM が出した白文を KanbunParserService に通した kakikudashi_exact（暫定出力なら false）。

PASSIVE = %w[彼は敵に殺された 私は先生に褒められた 花は風に散らされた 彼は人に笑われた
             魚は猫に食べられた 彼は王に用いられた 城は敵に破られた 彼は友に助けられた].freeze
CONTROL = %w[彼は敵を殺した 私は人に学ぶ 彼は森に入った 私は先生に問うた].freeze

runs = (ENV["RUNS"] || 3).to_i
expected = {}
groups =
  if ARGV[0].to_s.end_with?(".tsv")
    lines = File.readlines(ARGV[0], chomp: true).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
    sentences = lines.map do |line|
      text, *answers = line.split("\t").map(&:strip)
      expected[text] = answers
      text
    end
    { "ベンチ" => sentences }
  else
    { "受身" => PASSIVE, "対照" => CONTROL }
  end

summary = []
groups.each do |name, sentences|
  puts "## #{name}"
  sentences.each do |text|
    cells = Array.new(runs) do
      r = KanbunTranslatorService.call(text)
      { skeleton: r.skeleton, hakubun: r.hakubun, exact: r.kakikudashi_exact == true,
        reasons: Array(r.kakikudashi_reasons), parsed: r.parse_error.nil?,
        match: expected.key?(text) ? expected[text].include?(r.hakubun) : nil }
    end
    cells.each_with_index do |c, i|
      puts "#{text}\t##{i + 1}\t骨格:#{c[:skeleton]}\t白文:#{c[:hakubun]}\texact:#{c[:exact]}\treasons:#{c[:reasons].join(' / ')}"
    end
    summary << [name, text, cells.count { |c| c[:skeleton].to_s.include?("被") }, cells.count { |c| c[:hakubun].include?("被") },
                cells.count { |c| c[:exact] }, cells.count { |c| c[:hakubun].include?("被") && c[:exact] },
                cells.count { |c| c[:match] }, cells.map { |c| c[:hakubun] }.uniq.size]
  end
end

puts "\n## 集計（#{runs} 回ずつ）"
puts %w[組 文 骨格に被 白文に被 exact 被かつexact 期待一致 白文の種類数].join("\t")
summary.each { |row| puts row.join("\t") }
puts "合計\t\t#{summary.sum { _1[2] }}\t#{summary.sum { _1[3] }}\t#{summary.sum { _1[4] }}\t#{summary.sum { _1[5] }}\t#{summary.sum { _1[6] }}\t"
