require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/kunten").to_s
require Rails.root.join("lib/kanbun/yomi").to_s

# 構文木 → 書き下し（歴史的仮名遣い）。Phase 5a M6。
# 期待値は自作文または原典の句（論語・孟子・荘子など）を、自分で書き下したもの。
RSpec.describe Kanbun::Yomi do
  def kaki(hakubun)
    described_class.kakikudashi(KanbunParser.new.parse_tree(hakubun, strict: true))
  end

  def self.kaki_cases(title, rows)
    describe title do
      rows.each do |hakubun, expected|
        it "#{hakubun} => #{expected}" do
          expect(kaki(hakubun)).to eq expected
        end
      end
    end
  end

  kaki_cases "基本五文型・補語（於の助詞は述語の格で決まる）", [
    %w[我読漢文 我は漢文を読む], %w[我知之 我は之を知る], %w[返景入深林 返景深林に入る],
    %w[問礼於老子 礼を老子に問ふ], %w[学於人 人に学ぶ], %w[苛政猛於虎 苛政虎より猛し],
    %w[霜葉紅於二月花 霜葉二月花より紅なり], %w[君子揚名後世 君子名を後世に揚ぐ],
    %w[花開鳥啼 花開き鳥啼く], %w[人皆死 人皆死す]
  ]

  kaki_cases "否定・禁止・二重否定", [
    %w[不学 学ばず], %w[不読書 書を読まず], %w[勿待人 人を待つこと勿かれ],
    %w[無不陥 陥らざる無し], %w[無人 人無し], %w[我無所知 我は知る所無し],
    %w[不得不知 知らざるを得ず], %w[不可不行 行かざるべからず],
    %w[不可不学於師 師に学ばざるべからず], %w[無非君子 君子に非ざる無し],
    %w[非不慎 慎まざるに非ず], %w[不知非恥 知らざるは恥に非ず], %w[彼非君子 彼は君子に非ず]
  ]

  kaki_cases "再読文字（2 度目の読みは返り点が閉じる位置に付く）", [
    %w[未知 未だ知らず], %w[将行 将に行かんとす], %w[当学 当に学ぶべし], %w[応知 応に知るべし],
    %w[宜学 宜しく学ぶべし], %w[須学 須らく学ぶべし], %w[猶不及 猶ほ及ばざるがごとし],
    %w[盍行 盍ぞ行かざる], %w[未知故郷事 未だ故郷の事を知らず]
  ]

  kaki_cases "比況・比較・累加・受身・疑問", [
    %w[其疾如風 其の疾きこと風のごとし], %w[人生如夢 人生は夢のごとし],
    %w[人莫若友 人は友に若くは莫し], %w[人不如友 人は友に如かず],
    %w[非徒無益 徒だに益無きのみに非ず], %w[不独無益 独り益無きのみならず],
    %w[非徒無益而又害之 徒だに益無きのみに非ず、而も又た之を害ふ],
    %w[彼為敵所殺 彼は敵の殺す所と為る], %w[被殺 殺さる],
    %w[不亦説乎 亦た説ばしからずや]
  ]

  kaki_cases "置き字は出ない（矣・焉・接続の而）", [
    %w[行而学矣 行きて学ぶ], %w[学而不行 学びて行かず], %w[学焉 学ぶ], %w[入於深林焉 深林に入る]
  ]

  kaki_cases "文末助字", [
    %w[君子也 君子なり], %w[学也 学ぶなり], %w[学哉 学ぶかな], %w[学乎 学ぶや]
  ]

  kaki_cases "則・仮定（若A則B）", [
    %w[不学則不知道 学ばざれば則ち道を知らず], %w[若不学則愚 若し学ばざれば則ち愚かなり],
    %w[若学則楽 若し学べば則ち楽し]
  ]

  describe "辞書にない語・扱えない句法は黙って誤らず MissingEntry" do
    it "若A（則なし）は ずんば の形になるため MissingEntry" do
      tree = KanbunParser.new.parse_tree("若不学", strict: true)
      expect { described_class.kakikudashi(tree) }.to raise_error(Kanbun::Yomi::MissingEntry)
    end

    it "読みの辞書にない語は MissingEntry" do
      tree = KanbunParser.new.parse_tree("寧為無為", strict: true)
      expect { described_class.kakikudashi(tree) }.to raise_error(Kanbun::Yomi::MissingEntry)
    end
  end

  describe "復文の検査（書き下しが白文と矛盾しないか）" do
    def analyze(hakubun)
      tree = KanbunParser.new.parse_tree(hakubun, strict: true)
      reading = Kanbun::Kunten.reading(Kanbun::Kunten.annotate(tree))
      described_class.analyze(tree, reading: reading)
    end

    # 辞書の範囲で書き下せる白文はすべて、検査に通る（ベンチの期待白文と、この spec の全句）
    corpus = File.readlines(Rails.root.join("script/bench_expected.tsv"), chomp: true)
                 .reject { |l| l.strip.empty? || l.start_with?("#") }
                 .flat_map { |l| l.split("\t")[1..] }
    corpus += %w[未知 将行 当学 応知 宜学 須学 猶不及 盍行 不得不知 不可不学於師 非徒無益而又害之
                 彼為敵所殺 被殺 其疾如風 人生如夢 人莫若友 人不如友 学而不行 行而学矣 入於深林焉
                 問礼於老子 不亦説乎 若不学則愚 無不知者 不知非恥]
    corpus.uniq.each do |hakubun|
      it "#{hakubun} は復文検査に通る（書けないものは MissingEntry か解析不可）" do
        result = analyze(hakubun)
        expect(result.problems).to be_empty
      rescue Kanbun::Yomi::MissingEntry, Racc::ParseError, KanbunParser::UnknownCharacters
        skip "書き下しの対象外"
      end
    end

    it "読む順が返り点と食い違えば検出する" do
      tree = KanbunParser.new.parse_tree("我読漢文", strict: true)
      result = described_class.analyze(tree, reading: "我読漢文")
      expect(result.problems.join).to include("読む順")
    end

    it "置き字が書き下しに出ていれば検出する" do
      tree = KanbunParser.new.parse_tree("学焉", strict: true)
      item = described_class.collect(tree).last
      expect(described_class.item_problems(item, "ここに")).to include(a_string_matching(/置き字 焉/))
      expect(described_class.item_problems(item, "")).to be_empty
    end

    it "実字の漢字が書き下しから落ちていれば検出する" do
      tree = KanbunParser.new.parse_tree("我読漢文", strict: true)
      items = described_class.collect(tree)
      expect(described_class.item_problems(items.last, "よむ")).to include(a_string_matching(/実字 読/))
      expect(described_class.item_problems(items.last, "")).to include(a_string_matching(/落ちて/))
    end

    it "再読文字の 1 度目と 2 度目が対になっていなければ検出する" do
      tree = KanbunParser.new.parse_tree("未知", strict: true)
      items = described_class.collect(tree)
      items.pop
      out = items.map { "x" }
      expect(described_class.fukubun_problems(items, out, nil)).to include(a_string_matching(/対になっていません/))
    end
  end

  describe "曖昧な句形は exact と名乗らない" do
    def ambiguous(hakubun)
      tree = KanbunParser.new.parse_tree(hakubun, strict: true)
      described_class.analyze(tree).ambiguities
    end

    it "他動詞＋於A（殺於敵）は受身か能動か決まらない" do
      expect(ambiguous("殺於敵")).to include(a_string_matching(/受身か能動か/))
    end

    it "為A V（所なし）は受身かもしれない" do
      expect(ambiguous("為敵殺")).to include(a_string_matching(/所なし/))
    end

    it "意味の決まる句は曖昧としない（目的語つきの於・為A所B・被V・自動詞＋於）" do
      %w[兄釣魚於海 問礼於老子 彼為敵所殺 被殺 見殺 氷冷於水 入於深林 我読漢文].each do |s|
        expect(ambiguous(s)).to be_empty, s
      end
    end
  end

  describe "復文の検査（置き字・再読文字・字数）" do
    it "書き下しには置き字（矣・焉・於・接続の而）の字が出ない" do
      %w[行而学矣 学焉 入於深林焉 問礼於老子].each do |s|
        expect(kaki(s)).not_to match(/[矣焉於而]/), s
      end
    end

    it "再読文字は 2 度出る（1 度目の漢字と 2 度目の助動詞）" do
      expect(kaki("未知")).to eq("未だ知らず").and include("未").and include("ず")
      expect(kaki("当学")).to include("べし")
    end

    it "書き下しの実字（漢字）は、白文の字のうち助字を除いたものが全て順序を変えて含まれる" do
      expect(kaki("我読漢文").delete("はをむ")).to eq "我漢文読"
    end
  end
end
