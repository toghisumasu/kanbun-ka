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

  # ---- Phase 4a: 辞書による最長一致トークン化 ----
  cases "Phase 4a: 複数字語を 1 語として解析", [
    %w[深林 深林], %w[漢文 漢文], %w[老子 老子], %w[兵法 兵法], %w[二月花 二月花],
    %w[不学漢文 不学漢文], %w[読老子 読老子], %w[見聞 見聞], %w[不見聞 不見聞],
    %w[地不若深林 地不若深林], %w[無非王土 無非王土]
  ]

  cases "Phase 4a: 形容詞 ADJ", [
    %w[大 大], %w[不大 不大], %w[莫深 莫深]
  ]

  cases "Phase 4a: 句読点は読み飛ばす", [
    %w[学、読 学読], %w[不学。 不学]
  ]

  describe "Phase 4a: トークン列" do
    def tokens_of(str) = parser.send(:tokenize, str)

    it "深林 は NOUN 1 個（深+林 に割れない）" do
      expect(tokens_of("深林")).to eq [[:NOUN, "深林"], [false, nil]]
    end

    it "不亦 は FUKI_MATA（不 + 亦 に割れない）" do
      expect(tokens_of("不亦説乎").first).to eq [:FUKI_MATA, "不亦"]
    end

    it "深 単独は ADJ" do
      expect(tokens_of("深").first).to eq [:ADJ, "深"]
    end

    it "言 は VERB が優先（従来どおり）" do
      expect(tokens_of("言").first).to eq [:VERB, "言"]
    end

    it "辞書にない文字は skipped に記録される" do
      parser.parse("学Ｘ読")
      expect(parser.skipped).to eq ["Ｘ"]
    end

    it "句読点は skipped に入れない" do
      parser.parse("学、読。")
      expect(parser.skipped).to be_empty
    end
  end
end
