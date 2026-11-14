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
sents.each do |h|
  r = KanbunParserService.call(h)
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
