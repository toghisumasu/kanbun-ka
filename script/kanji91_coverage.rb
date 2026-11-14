# frozen_string_literal: true

# 字のリスト（1 行 1 字の TSV）が、白文側（Lexicon）と読み側（Yomi）でどこまで扱えるかの表を出す。
#   bin/rails runner script/kanji91_coverage.rb [docs/kanji91.tsv]
# 既定の入力は docs/kanji91.tsv（手元のみ。.gitignore 済み。git の管理下なら中止する）。
KanbunParserService # lib/kanbun の読み込み
require Rails.root.join("lib/kanbun/kanji_coverage").to_s

begin
  Kanbun::KanjiCoverage.run(ARGV[0] || Kanbun::KanjiCoverage::DEFAULT_PATH)
rescue Kanbun::KanjiCoverage::TrackedFile, Kanbun::KanjiCoverage::MissingFile, Kanbun::KanjiCoverage::BadLine => e
  warn "中止: #{e.message}"
  exit 1
end
