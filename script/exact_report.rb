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
rows.each do |line|
  hakubun = line.split("\t")[1]
  r = KanbunParserService.call(hakubun)
  puts [r[:kakikudashi_exact] ? "EXACT" : "-----", hakubun, r[:kakikudashi],
        Array(r[:kakikudashi_reasons]).join(" / "), r[:error]].join("\t")
end
