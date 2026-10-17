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

  # ---- Phase 4b: 基本構文 5 文型と置字（HB p.150） ----
  cases "Phase 4b: ① 主語＋述語", [
    %w[花開鳥啼 花開鳥啼], %w[山紫水明 山紫水明], %w[孔子聖人 孔子聖人]
  ]

  cases "Phase 4b: ② 主語＋述語＋目的語", [
    %w[我読漢文 我読漢文], %w[君子学道 君子学道]
  ]

  cases "Phase 4b: ③ 主語＋述語＋(於・于・乎)＋補語", [
    %w[返景入深林 返景入深林], %w[苛政猛於虎 苛政猛於虎],
    %w[霜葉紅於二月花 霜葉紅於二月花], %w[入乎深林 入乎深林], %w[花開于山 花開于山]
  ]

  cases "Phase 4b: ④ 目的語＋補語 / ⑤ 補語＋目的語", [
    %w[君子揚名後世 君子揚名後世], %w[子問礼於老子 子問礼於老子],
    %w[項梁教籍兵法 項梁教籍兵法], %w[陽貨帰孔子豚 陽貨帰孔子豚]
  ]

  cases "Phase 4b: 句法の中に 5 文型が入る", [
    %w[不入深林 不入深林], %w[豈学道哉 豈学道哉], %w[何為入深林 何為入深林],
    %w[独君子有船 独君子有船], %w[若不入深林 若不入深林]
  ]

  describe "Phase 4b: 置字 乎 の先読み" do
    def tokens_of(str) = parser.send(:tokenize, str)

    it "乎 + 名詞 は置字 PREP" do
      expect(tokens_of("入乎深林")[1]).to eq [:PREP, "乎"]
    end

    it "文末の 乎 は疑問の SHI_KO" do
      expect(tokens_of("学乎")[1]).to eq [:SHI_KO, "乎"]
    end

    it "乎 + 哉 など助字が続くときは SHI_KO のまま" do
      expect(tokens_of("学乎哉")[1]).to eq [:SHI_KO, "乎"]
    end

    it "於 于 は常に PREP" do
      expect(tokens_of("入於山")[1]).to eq [:PREP, "於"]
      expect(tokens_of("入于山")[1]).to eq [:PREP, "于"]
    end

    it "自動詞のあとに名詞が続く 花開鳥 は文法上受理しない（開は自動詞）" do
      expect { parser.parse("花開鳥") }.to raise_error(Racc::ParseError)
    end
  end
end
