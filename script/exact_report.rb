# frozen_string_literal: true

# ベンチの期待白文（script/bench_expected.tsv の各行の先頭の白文）を KanbunParserService に通し、
# kakikudashi_exact と理由を TSV で出す。導入前後の比較用（Phase 5b S4）。
#
#   bin/rails runner script/exact_report.rb > tmp/exact_before.tsv
#   bin/rails runner script/exact_report.rb > tmp/exact_after.tsv
#   diff tmp/exact_before.tsv tmp/exact_after.tsv

KanbunParserService # lib/kanbun を読み込む

rows = File.readlines(Rails.root.join("script/bench_expected.tsv"), chomp: true)
           .reject { |l| l.strip.empty? || l.start_with?("#") }
count = Hash.new(0)
usage = Hash.new(0)
rows.each do |line|
  hakubun = line.split("\t")[1]
  r = KanbunParserService.call(hakubun)
  count[:parsed] += 1 if r[:status] == :parsed
  count[:tree_ok] += 1 if r[:kakikudashi_tree_ok]
  count[:verified] += 1 if r[:status] == :parsed && r[:kakikudashi_verified]
  count[:exact] += 1 if r[:kakikudashi_exact]
  Array(r[:kakikudashi_unverified]).each { |id| usage[id] += 1 }
  puts [r[:kakikudashi_exact] ? "EXACT" : "-----", hakubun, r[:kakikudashi],
        Array(r[:kakikudashi_reasons]).join(" / "), r[:error]].join("\t")
end
# 標準出力は TSV の比較用に変えない。集計は標準エラーに出す（Phase 6a S5）。
warn "文数 #{rows.size}: 解析 #{count[:parsed]} / tree_ok #{count[:tree_ok]} / verified #{count[:verified]} / exact #{count[:exact]}"
warn "未確認項目の使用頻度（上位30。DEFAULT は既定値で補った読み）:"
usage.sort_by { |id, n| [-n, id] }.first(30).each { |id, n| warn format("  %4d  %s", n, id) }
