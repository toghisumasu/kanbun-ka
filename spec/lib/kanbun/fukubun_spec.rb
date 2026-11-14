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

  # phase5a の Yomi.fukubun_problems にあって S2 で落ちていた検査（S5 で復活）
  describe "5. 置き字が書き下しに出ていない" do
    it "焉 が出ていれば 置き字が書き下しに出ている: 焉" do
      expect(check("学焉", "学び焉")).to include("置き字が書き下しに出ている: 焉")
    end

    it "於 が出ていれば検出する" do
      expect(check("問礼於老子", "礼を於老子に問ふ")).to include("置き字が書き下しに出ている: 於")
    end

    it "矣・而 が出ていれば検出する" do
      expect(check("行而学矣", "行きて学ぶ矣")).to include("置き字が書き下しに出ている: 矣")
      expect(check("行而学矣", "行き而学ぶ")).to include("置き字が書き下しに出ている: 而")
    end

    it "置き字が出ていなければ違反なし（於・焉・而・矣）" do
      expect(check("入於深林焉", "深林に入る")).to eq []
      expect(check("行而学矣", "行きて学ぶ")).to eq []
    end

    it "累加の 而 は「、而も」と読むので、置き字として数えない" do
      expect(check("非徒無益而又害之", "徒だに益無きのみに非ず、而も又た之を害ふ")).to eq []
    end

    it "与A・自A・従A は字を出さず助詞になる（置き字の違反にも欠落にもならない）" do
      expect(check("与友飲酒而語", "友と酒を飲みて語る")).to eq []
    end
  end

  # phase5a の yomi_spec にあった「ベンチの期待白文と固定文は、辞書の範囲で書き下せるものすべて検査に通る」
  describe "正例：ベンチの期待白文と固定文（Yomi の書き下しに対して）" do
    require Rails.root.join("lib/kanbun/yomi").to_s
    corpus = File.readlines(Rails.root.join("script/bench_expected.tsv"), chomp: true)
                 .reject { |l| l.strip.empty? || l.start_with?("#") }
                 .flat_map { |l| l.split("\t")[1..] }
    corpus += %w[未知 将行 当学 応知 宜学 須学 猶不及 盍行 不得不知 不可不学於師 非徒無益而又害之
                 彼為敵所殺 被殺 其疾如風 人生如夢 人莫若友 人不如友 学而不行 行而学矣 入於深林焉
                 問礼於老子 不亦説乎 若不学則愚 無不知者 不知非恥]
    corpus.uniq.each do |hakubun|
      it "#{hakubun} は復文検査に通る（書けないものは MissingEntry か解析不可）" do
        tree = KanbunParser.new.parse_tree(hakubun, strict: true)
        expect(described_class.check(tree, Kanbun::Yomi.analyze(tree).text)).to eq []
      rescue Kanbun::Yomi::MissingEntry, Racc::ParseError, KanbunParser::UnknownCharacters
        skip "書き下しの対象外"
      end
    end
  end

  # S6: Yomi が返す項目（構文木の葉と、その書き下し断片）を使う検査。
  #   機能語（不・之・者・所…）の欠落と、実字の位置（別の位置に同じ字があっても通さない）
  describe "6. 項目ごとの検査（機能語の欠落・実字の位置）" do
    require Rails.root.join("lib/kanbun/yomi").to_s

    def analyzed(hakubun)
      tree = KanbunParser.new.parse_tree(hakubun, strict: true)
      [tree, Kanbun::Yomi.analyze(tree)]
    end

    # surface の項目の断片を text に差し替えた壊れた項目列で検査する
    def check_with(hakubun, surface, text, nth: 0)
      tree, result = analyzed(hakubun)
      parts = result.parts.map { |pc| pc.dup }
      parts.select { |pc| pc.leaf.surface == surface }[nth].text = text
      described_class.check(tree, parts.map(&:text).join, parts: parts)
    end

    it "Yomi の結果は、項目ごとの葉と断片を持ち、断片をつなぐと書き下しになる" do
      _tree, result = analyzed("我読漢文")
      expect(result.parts.map(&:text).join).to eq result.text
      expect(result.parts.map { |pc| pc.leaf.surface }).to eq %w[我 漢文 読]
    end

    it "不 が落ちた書き下しを検出する（読みの順は変わらない）" do
      expect(check_with("不読書", "不", "")).to include("機能語の欠落: 不")
    end

    it "之 が落ちた書き下しを検出する" do
      # 之 は辞書上 実字（NOUN）なので「字の欠落」として検出される
      expect(check_with("我知之", "之", "")).to include(a_string_matching(/欠落: 之/))
    end

    it "実字が別の位置に出る書き下しを検出する（字の数も順も合っている）" do
      tree, result = analyzed("我読漢文")
      parts = result.parts.map(&:dup)
      parts.find { |pc| pc.leaf.surface == "漢文" }.text = "漢文を読"
      parts.find { |pc| pc.leaf.surface == "読" }.text = "む"
      text = parts.map(&:text).join
      expect(text).to eq result.text
      expect(described_class.check(tree, text)).to eq []
      expect(described_class.check(tree, text, parts: parts)).to include("実字の位置: 読")
    end

    it "与A・自A・従A は字を出さない（助詞が名詞の送り仮名になる）ので欠落としない" do
      tree, result = analyzed("与友飲酒而語")
      yo = result.parts.find { |pc| pc.leaf.surface == "与" }
      expect(yo.text).to eq ""
      expect(described_class.check(tree, result.text, parts: result.parts)).to eq []
    end

    it "断片をつないだものが書き下しと違えば検出する" do
      tree, result = analyzed("我読漢文")
      expect(described_class.check(tree, "我は漢文を読む。", parts: result.parts)).to include(a_string_matching(/断片/))
    end

    it "正例：ベンチの期待白文と固定文は、項目つきの検査でも通る" do
      corpus = File.readlines(Rails.root.join("script/bench_expected.tsv"), chomp: true)
                   .reject { |l| l.strip.empty? || l.start_with?("#") }
                   .flat_map { |l| l.split("\t")[1..] }
      corpus += %w[未知 将行 当学 盍行 不得不知 不可不学於師 非徒無益而又害之 彼為敵所殺 被殺 見殺
                   其疾如風 人莫若友 学而不行 行而学矣 入於深林焉 問礼於老子 不亦説乎 与友飲酒而語]
      checked = 0
      failures = corpus.uniq.filter_map do |hakubun|
        tree, result = analyzed(hakubun)
        checked += 1
        reasons = described_class.check(tree, result.text, parts: result.parts)
        "#{hakubun}: #{reasons.join(' / ')}" unless reasons.empty?
      rescue Kanbun::Yomi::MissingEntry, Racc::ParseError, KanbunParser::UnknownCharacters
        nil
      end
      expect(checked).to be > 20
      expect(failures).to eq []
    end
  end
end
