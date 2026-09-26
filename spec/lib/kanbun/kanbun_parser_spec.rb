require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s

RSpec.describe KanbunParser do
  let(:parser) { described_class.new }

  # 入力と期待値の組をまとめて検証するヘルパー
  def self.cases(title, pairs)
    describe title do
      pairs.each do |input, expected|
        it "#{input} => #{expected}" do
          expect(parser.parse(input)).to eq expected
        end
      end
    end
  end

  cases "Phase 1: 否定・禁止", [
    %w[不学 不学], %w[不読書 不読書], %w[莫笑 莫笑]
  ]

  cases "Phase 2a: 二重否定", [
    %w[無非王土 無非王土], %w[無不陥 無不陥], %w[非不慎 非不慎]
  ]

  cases "Phase 2a: 部分否定", [
    %w[不必賢 不必賢], %w[不常有 不常有], %w[不復得 不復得]
  ]

  cases "Phase 2b: 比較・選択・抑揚", [
    %w[計莫如植 計莫如植], %w[地不若人 地不若人],
    %w[与易寧戚 与易寧戚], %w[寧為無為 寧為無為],
    %w[馬況人乎 馬況人乎]
  ]

  cases "Phase 3a: 仮定・逆接・限定", [
    %w[若不成 若不成], %w[如不成 如不成], %w[苟無成 苟無成],
    %w[学雖無成 学雖無成], %w[惟士 惟士], %w[独臣有船 独臣有船]
  ]

  cases "Phase 3b: 疑問", [
    %w[学乎 学乎], %w[学邪 学邪], %w[学与 学与]
  ]

  cases "Phase 3b: 反語", [
    %w[豈学哉 豈学哉], %w[不亦説乎 不亦説乎],
    %w[寧有乎 寧有乎], %w[独学乎 独学乎]
  ]

  cases "Phase 3b: 疑問副詞", [
    %w[安在 安在], %w[孰臣賢 孰臣賢], %w[何為行 何為行],
    %w[何以知 何以知], %w[如何行 如何行]
  ]
end
