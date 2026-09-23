require "rails_helper"

RSpec.describe KanbunBNFParser do
  # ────────────────────────────────────
  # テスト用トークン生成ヘルパー
  # ────────────────────────────────────
  def tok(surface, pos_type, base_form = nil)
    KanbunBNFParser::Token.new(
      surface:   surface,
      pos_type:  pos_type,
      base_form: base_form || surface
    )
  end

  def parse(tokens)
    described_class.new(tokens).parse
  end

  # ────────────────────────────────────
  # 既存: 動詞文（回帰テスト）
  # ────────────────────────────────────
  describe "verbal_sentence（回帰）" do
    context "他動詞文: 私は林檎を食べる" do
      let(:tokens) do
        [tok("私", :pron), tok("は", :wa), tok("林檎", :noun),
         tok("を", :wo), tok("食べ", :verb, "食べる")]
      end
      it { expect(parse(tokens).sentence_type).to eq :transitive }
      it { expect(parse(tokens).to_kanbun_hint).to include("述語: 食べる") }
    end

    context "自動詞文: 犬が走る" do
      let(:tokens) do
        [tok("犬", :noun), tok("が", :ga), tok("走る", :verb)]
      end
      it { expect(parse(tokens).sentence_type).to eq :intransitive }
    end

    context "否定文: 私は食べない" do
      let(:tokens) do
        [tok("私", :pron), tok("は", :wa),
         tok("食べ", :verb, "食べる"), tok("ない", :neg)]
      end
      it { expect(parse(tokens).negated).to eq true }
      it { expect(parse(tokens).to_kanbun_hint).to include("不＋述語") }
    end

    context "使役文: 王は人を行かせた" do
      let(:tokens) do
        [tok("王", :noun), tok("は", :wa),
         tok("人", :noun), tok("を", :wo),
         tok("行か", :verb, "行く"), tok("せ", :causative), tok("た", :past)]
      end
      it { expect(parse(tokens).causative).to eq true }
      it { expect(parse(tokens).to_kanbun_hint).to include("[使役 → 使構文]") }
    end
  end

  # ────────────────────────────────────
  # 新規: 連動文（て形連接）
  # ────────────────────────────────────
  describe "sequential_sentence" do
    context "王は民を集めて号令した" do
      let(:tokens) do
        [tok("王", :noun), tok("は", :wa),
         tok("民", :noun), tok("を", :wo),
         tok("集め", :verb, "集める"), tok("て", :conj_te),
         tok("号令し", :verb, "号令する"), tok("た", :past)]
      end
      subject(:result) { parse(tokens) }

      it { expect(result.sentence_type).to eq :sequential }
      it { expect(result.chain.map(&:base_form)).to eq %w[集める 号令する] }
      it { expect(result.predicate.base_form).to eq "号令する" }
      it { expect(result.past).to eq true }
      it "ヒントに連動が含まれる" do
        expect(result.to_kanbun_hint).to include("連動: 集める→号令する")
      end
    end

    context "三連動: 起きて食べて出た" do
      let(:tokens) do
        [tok("起き", :verb, "起きる"), tok("て", :conj_te),
         tok("食べ", :verb, "食べる"), tok("て", :conj_te),
         tok("出", :verb, "出る"), tok("た", :past)]
      end
      it { expect(parse(tokens).chain.size).to eq 3 }
    end

    context "て形なし（単動詞）は verbal_sentence に委譲" do
      let(:tokens) do
        [tok("犬", :noun), tok("が", :ga),
         tok("走っ", :verb, "走る"), tok("た", :past)]
      end
      it { expect(parse(tokens).sentence_type).to eq :intransitive }
    end
  end

  # ────────────────────────────────────
  # 新規: 比較文
  # ────────────────────────────────────
  describe "comparative_sentence" do
    context "馬は牛より速い" do
      let(:tokens) do
        [tok("馬", :noun), tok("は", :wa),
         tok("牛", :noun), tok("より", :yori),
         tok("速い", :adj, "速い")]
      end
      subject(:result) { parse(tokens) }

      it { expect(result.sentence_type).to eq :comparative }
      it { expect(result.predicate.base_form).to eq "速い" }
      it { expect(result.negated).to eq false }
      it "ヒントに莫如が含まれる" do
        expect(result.to_kanbun_hint).to include("莫如")
      end
    end

    context "否定比較: 地の利は人の和より優れない（不若構文）" do
      let(:tokens) do
        [tok("地", :noun), tok("は", :wa),
         tok("人", :noun), tok("より", :yori),
         tok("優れ", :verb, "優れる"), tok("ない", :neg)]
      end
      subject(:result) { parse(tokens) }

      it { expect(result.negated).to eq true }
      it "ヒントに不若が含まれる" do
        expect(result.to_kanbun_hint).to include("不若")
      end
    end
  end

  # ────────────────────────────────────
  # 新規: 疑問マーカー
  # ────────────────────────────────────
  describe "question マーカー" do
    context "汝は勇を好むか" do
      let(:tokens) do
        [tok("汝", :pron), tok("は", :wa),
         tok("勇", :noun), tok("を", :wo),
         tok("好む", :verb), tok("か", :question)]
      end
      subject(:result) { parse(tokens) }

      it { expect(result.question).to eq true }
      it "ヒントに乎/哉が含まれる" do
        expect(result.to_kanbun_hint).to include("乎/哉")
      end
    end

    context "疑問マーカーなし → question: false" do
      let(:tokens) do
        [tok("汝", :pron), tok("は", :wa), tok("行く", :verb)]
      end
      it { expect(parse(tokens).question).to eq false }
    end
  end

  # ────────────────────────────────────
  # エッジケース
  # ────────────────────────────────────
  describe "パース失敗ケース" do
    it "空配列 → nil" do
      expect(parse([])).to be_nil
    end

    it "述語なし（名詞のみ）→ nil" do
      expect(parse([tok("王", :noun), tok("は", :wa)])).to be_nil
    end

    it "全トークン未消費 → nil" do
      # 余分なトークンが末尾にあるとパース失敗
      tokens = [tok("犬", :noun), tok("が", :ga),
                tok("走る", :verb), tok("余", :noun)]
      expect(parse(tokens)).to be_nil
    end
  end
end

