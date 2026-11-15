# frozen_string_literal: true

# ベンチの別表記と spec に出てくる漢字の文を全部 KanbunParserService に通し、復文検査の違反が出た文を列挙する（Phase 5b S4）。
#   bin/rails runner script/exact_wide_report.rb

KanbunParserService
sents = []
File.readlines("script/bench_expected.tsv", chomp: true).reject { |l| l.strip.empty? || l.start_with?("#") }.each { |l| sents.concat(l.split("\t")[1..]) }
Dir["spec/**/*_spec.rb"].each do |f|
  File.read(f).scan(/%w\[([^\]]+)\]/).each { |m| m[0].split.each { |w| sents << w if w.match?(/\A\p{Han}+\z/) } }
  File.read(f).scan(/"([\p{Han}]{2,12})"/).each { |m| sents << m[0] }
end
sents = sents.uniq
exact = viol = other = 0
count = Hash.new(0)
usage = Hash.new(0)
sents.each do |h|
  r = KanbunParserService.call(h)
  count[:parsed] += 1 if r[:status] == :parsed
  count[:tree_ok] += 1 if r[:kakikudashi_tree_ok]
  count[:exact] += 1 if r[:kakikudashi_exact]
  count[:verified] += 1 if r[:status] == :parsed && r[:kakikudashi_verified]
  Array(r[:kakikudashi_unverified]).each { |id| usage[id] += 1 }
  if r[:status] != :parsed then other += 1
  elsif r[:kakikudashi_exact] then exact += 1
  else
    reasons = r[:kakikudashi_reasons]
    if reasons.any? { |x| x.start_with?("字の", "読み順", "再読") }
      viol += 1
      puts "VIOLATION\t#{h}\t#{r[:kakikudashi]}\t#{reasons.join(' / ')}"
    else other += 1
    end
  end
end
puts "文数 #{sents.size}: exact #{exact} / 復文検査の違反 #{viol} / その他(解析不可・辞書外・曖昧) #{other}"
# Phase 6a S5: tree_ok（従来の exact）／verified（使った項目がすべて確認済み）／exact（両方）
puts "文数 #{sents.size}: 解析 #{count[:parsed]} / tree_ok #{count[:tree_ok]} / verified #{count[:verified]} / exact #{count[:exact]}"
puts "未確認項目の使用頻度（上位30。DEFAULT は既定値で補った読み）:"
usage.sort_by { |id, n| [-n, id] }.first(30).each { |id, n| puts format("  %4d  %s", n, id) }
