require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/kunten").to_s
require Rails.root.join("lib/kanbun/fukubun").to_s

# Phase 5b S2: 復文検査。白文（構文木）と書き下しを比べて、違反の理由（文字列）の配列を返す。
# 検査項目: 1 実字の漢字が全部残っている  2 再読文字が 2 度出る
#           3 返り点を適用した順と書き下しの読み順が一致する（Kanbun::Reorder）  4 字の重複がない
RSpec.describe Kanbun::Fukubun do
  def check(hakubun, kakikudashi)
    described_class.check(KanbunParser.new.parse_tree(hakubun, strict: true), kakikudashi)
  end

  # 正例：既存の固定文（yomi_spec・service spec の期待値）。違反なし。
  describe "正しい書き下しは違反なし" do
    {
      "我読漢文" => "我は漢文を読む", "我知之" => "我は之を知る", "問礼於老子" => "礼を老子に問ふ",
      "学於人" => "人に学ぶ", "苛政猛於虎" => "苛政虎より猛し", "君子揚名後世" => "君子名を後世に揚ぐ",
      "花開鳥啼" => "花開き鳥啼く", "不読書" => "書を読まず", "勿待人" => "人を待つこと勿かれ",
      "無不陥" => "陥らざる無し", "不得不知" => "知らざるを得ず", "不可不学於師" => "師に学ばざるべからず",
      "未知" => "未だ知らず", "将行" => "将に行かんとす", "当学" => "当に学ぶべし",
      "猶不及" => "猶ほ及ばざるがごとし", "盍行" => "盍ぞ行かざる", "其疾如風" => "其の疾きこと風のごとし",
      "人莫若友" => "人は友に若くは莫し", "彼為敵所殺" => "彼は敵の殺す所と為る", "被殺" => "殺さる",
      "見殺" => "殺さる", "不亦説乎" => "亦た説ばしからずや", "行而学矣" => "行きて学ぶ",
      "与友飲酒而語" => "友と酒を飲みて語る", "非徒無益而又害之" => "徒だに益無きのみに非ず、而も又た之を害ふ"
    }.each do |hakubun, kaki|
      it "#{hakubun} => #{kaki}" do
        expect(check(hakubun, kaki)).to eq []
      end
    end
  end

  describe "1. 実字の欠落" do
    it "漢文 が落ちていれば 字の欠落" do
      expect(check("我読漢文", "我は読む")).to include("字の欠落: 漢", "字の欠落: 文")
    end

    it "学 が落ちていれば 字の欠落: 学" do
      expect(check("不学", "ず")).to include("字の欠落: 学")
    end

    it "置き字（於・矣・焉）は、書き下しになくても欠落としない" do
      expect(check("学於人", "人に学ぶ")).to eq []
      expect(check("学焉", "学ぶ")).to eq []
    end

    it "見V の 見 は受身の助動詞（る）として読むので、実字の欠落としない" do
      expect(check("見殺", "殺さる")).to eq []
    end
  end

  describe "4. 字の重複" do
    it "読 が 2 度出ていれば 字の重複: 読" do
      expect(check("我読漢文", "我は漢文を読み読む")).to include("字の重複: 読")
    end
  end

  describe "3. 読み順（返り点を適用した順）" do
    it "読 と 漢文 が入れ替わっていれば 読み順の不一致" do
      reasons = check("我読漢文", "我は読む漢文を")
      expect(reasons.join).to include("読み順の不一致")
      expect(reasons.join).to include("期待 我漢文読")
    end

    it "レ点の読み順（不読書 は 書 読）" do
      expect(check("不読書", "読書を不")).to include(a_string_matching(/読み順の不一致/))
    end

    it "Kanbun::Reorder の結果と同じ順を期待する" do
      tree = KanbunParser.new.parse_tree("我読漢文", strict: true)
      units = Kanbun::Kunten.annotate(tree)
      expect(Kanbun::Reorder.reorder(units).map(&:kanji).join).to eq "我漢文読"
    end
  end

  describe "2. 再読文字" do
    it "2 度目の読み（ず）がなければ 再読文字が2度出ていない" do
      expect(check("未知", "未だ知る")).to include("再読文字が2度出ていない: 未")
    end

    it "1 度目（未）がなければ 再読文字が2度出ていない" do
      expect(check("未知", "知らず")).to include("再読文字が2度出ていない: 未")
    end

    it "べし の 当 は 2 度目の べ がなければ違反" do
      expect(check("当学", "当に学ぶ")).to include("再読文字が2度出ていない: 当")
    end
  end
end
