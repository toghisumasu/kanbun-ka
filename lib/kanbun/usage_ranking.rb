# frozen_string_literal: true

module Kanbun
  # 未確認項目の使用頻度を、種類ごとの上位 N に分ける（script/exact_report.rb・exact_wide_report.rb 用。Phase 6a 第2段）。
  module UsageRanking
    SECTIONS = [
      ['辞書の表', ->(id) { !id.match?(/\A(FUNC|RULE|DEFAULT):/) }],
      ['FUNC（直書きの機能語）', ->(id) { id.start_with?('FUNC:') }],
      ['RULE（文法規則）', ->(id) { id.start_with?('RULE:') }],
      ['DEFAULT（既定値）', ->(id) { id.start_with?('DEFAULT:') }]
    ].freeze

    # usage: { 項目ID => 使った文の数 }。[[見出し, [[ID, 数], ...]], ...]
    def self.sections(usage, top: 30)
      SECTIONS.map do |title, pick|
        rows = usage.select { |id, _| pick.call(id) }.sort_by { |id, n| [-n, id] }.first(top)
        [title, rows]
      end
    end

    def self.lines(usage, top: 30)
      sections(usage, top: top).flat_map do |title, rows|
        [title] + rows.map { |id, n| format('  %4d  %s', n, id) }
      end
    end
  end
end
