require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/yomi").to_s
require Rails.root.join("lib/kanbun/kanji_coverage").to_s
require "tempfile"
require "stringio"

# 調査3: 字のリスト（1 行 1 字の TSV）→ 白文側（Lexicon）と読み側（Yomi）のカバー表。
# ここでは本書と無関係な自作のダミー表（学・不・虹）だけを使う。実際のリストは手元のみ（リポジトリに入れない）。
RSpec.describe Kanbun::KanjiCoverage do
  def tsv(text)
    file = Tempfile.new(["kanji", ".tsv"])
    file.write(text)
    file.flush
    file
  end

  describe ".load_tsv" do
    it "1 行 1 字（字 TAB 任意のメモ）を読む。空行と # 行は無視する" do
      f = tsv("学\t動詞のつもり\n\n# 注\n不\n虹\t辞書にない字\n")
      expect(described_class.load_tsv(f.path)).to eq [["学", "動詞のつもり"], ["不", ""], ["虹", "辞書にない字"]]
    end

    it "1 字でない行は、行番号つきで報告して止まる" do
      f = tsv("学\n深林\n")
      expect { described_class.load_tsv(f.path) }.to raise_error(described_class::BadLine, /2 行目/)
    end
  end

  describe ".rows" do
    let(:rows) { described_class.rows([["学", "m1"], ["不", ""], ["虹", "m3"]]).to_h { |r| [r[:char], r] } }

    it "学：白文側は VERB、読み側は Yomi::VERBS（活用の型つき）" do
      expect(rows["学"][:hakubun]).to eq "VERB"
      expect(rows["学"][:yomi]).to match(/VERBS.*バ行|VERBS.*ba/)
      expect(rows["学"][:memo]).to eq "m1"
    end

    it "不：白文側は機能語（NEG_BU）、読み側は render の機能語" do
      expect(rows["不"][:hakubun]).to eq "NEG_BU"
      expect(rows["不"][:yomi]).to eq "機能語（render）"
    end

    it "虹：どちらにもない（白文側 なし／読み側 なし）" do
      expect(rows["虹"][:hakubun]).to eq "なし"
      expect(rows["虹"][:yomi]).to eq "なし"
    end

    it "白文側にあって読み側にない字は、読み側が なし（止まる側）と分かる" do
      expect(described_class.rows([["誰", ""]]).first).to include(hakubun: "GI_DARE", yomi: "なし")
    end
  end

  describe ".run" do
    it "表を出力する（字・白文側・読み側・メモ）" do
      f = tsv("学\tm\n虹\n")
      out = StringIO.new
      described_class.run(f.path, out: out)
      expect(out.string).to include("学\tVERB").and include("虹\tなし\tなし")
    end

    it "git の管理下にあるファイルなら、警告して中止する" do
      expect(described_class.tracked?(Rails.root.join("script/bench_expected.tsv").to_s)).to be true
      expect { described_class.run(Rails.root.join("script/bench_expected.tsv").to_s, out: StringIO.new) }
        .to raise_error(described_class::TrackedFile, /リポジトリには入れない/)
    end

    it "管理下にないファイル（一時ファイル）は tracked でない" do
      expect(described_class.tracked?(tsv("学\n").path)).to be false
    end

    it "ファイルがなければ、置き場所を示して止まる" do
      expect { described_class.run("/nonexistent/kanji91.tsv", out: StringIO.new) }
        .to raise_error(described_class::MissingFile, /kanji91\.tsv/)
    end
  end
end
