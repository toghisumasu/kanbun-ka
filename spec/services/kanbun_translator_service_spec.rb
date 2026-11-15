require "rails_helper"

RSpec.describe KanbunTranslatorService do
  # ---------------------------------------------------------
  # 外部依存をすべてモック化
  # ---------------------------------------------------------
  let(:mecab_output) do
    "私\t名詞,代名詞,一般,*,*,*,私,ワタシ,ワタシ\n" \
    "は\t助詞,係助詞,*,*,*,*,は,ハ,ワ\n"             \
    "林檎\t名詞,一般,*,*,*,*,林檎,リンゴ,リンゴ\n"   \
    "を\t助詞,格助詞,一般,*,*,*,を,ヲ,ヲ\n"          \
    "食べる\t動詞,自立,*,*,一段,基本形,食べる,タベル,タベル\n" \
    "EOS\n"
  end

  before do
    # run_mecab（シェル呼び出し）
    allow_any_instance_of(described_class)
      .to receive(:run_mecab).and_return(mecab_output)

    # MeCabAdapter.call → Token配列を返す
    tokens = [
      KanbunBNFParser::Token.new(surface: "私",  pos_type: :pron, base_form: "私"),
      KanbunBNFParser::Token.new(surface: "は",  pos_type: :wa,   base_form: "は"),
      KanbunBNFParser::Token.new(surface: "林檎", pos_type: :noun, base_form: "林檎"),
      KanbunBNFParser::Token.new(surface: "を",  pos_type: :wo,   base_form: "を"),
      KanbunBNFParser::Token.new(surface: "食べ", pos_type: :verb, base_form: "食べる"),
    ]
    allow(MeCabAdapter).to receive(:call).and_return(tokens)

    # Ollama
    allow_any_instance_of(described_class)
      .to receive(:call_ollama).and_return("我食林檎")

    # KanbunParserService
    allow(KanbunParserService)
      .to receive(:call)
      .with("我食林檎")
      .and_return({ kunten: "我[レ]食林檎", kakikudashi: "我林檎を食らふ" })
  end

  subject(:result) { described_class.call("私は林檎を食べる") }

  describe "書き下しの確かさ（exact・reasons）は呼び出し側にも返る（Phase 5b S7）" do
    it "exact:false と reasons を Result に載せる" do
      allow(KanbunParserService).to receive(:call).with("我食林檎").and_return(
        { kunten: "我[レ]食林檎", kakikudashi: "我林檎食", kakikudashi_exact: false,
          kakikudashi_reasons: ["他動詞＋於A は受身か能動か決まりません: 食於林檎"] }
      )
      expect(result.kakikudashi_exact).to be false
      expect(result.kakikudashi_reasons).to eq ["他動詞＋於A は受身か能動か決まりません: 食於林檎"]
    end
  end

  describe "確認済み印の項目も呼び出し側に返る（Phase 6a S4）" do
    it "tree_ok・verified・unverified を Result に載せる" do
      allow(KanbunParserService).to receive(:call).with("我食林檎").and_return(
        { kunten: "我[レ]食林檎", kakikudashi: "我は林檎を食らふ", kakikudashi_exact: false,
          kakikudashi_tree_ok: true, kakikudashi_verified: false,
          kakikudashi_unverified: ["VERBS:食"],
          kakikudashi_reasons: ["未確認の辞書項目: VERBS:食"] }
      )
      expect(result.kakikudashi_tree_ok).to be true
      expect(result.kakikudashi_verified).to be false
      expect(result.kakikudashi_unverified).to eq ["VERBS:食"]
    end
  end

  describe "正常系: BNFパースが成功する場合" do
    it "白文が返る" do
      expect(result.hakubun).to eq "我食林檎"
    end

    it "訓点付き漢文が返る" do
      expect(result.kunten).to eq "我[レ]食林檎"
    end

    it "書き下し文が返る" do
      expect(result.kakikudashi).to eq "我林檎を食らふ"
    end

    it "骨格が生成されている（fallback: false）" do
      expect(result.fallback).to eq false
      expect(result.skeleton).not_to be_nil
    end

    it "LLMに渡すプロンプトに骨格が含まれる" do
      expect_any_instance_of(described_class)
        .to receive(:call_ollama)
        .with(include("骨格"))
      described_class.call("私は林檎を食べる")
    end
  end

  describe "フォールバック: BNFパースが失敗する場合" do
    before do
      # BNFパーサーがnilを返す状況をシミュレート
      allow_any_instance_of(KanbunBNFParser).to receive(:parse).and_return(nil)
      allow_any_instance_of(described_class)
        .to receive(:call_ollama).and_return("複雑漢文")
      allow(KanbunParserService)
        .to receive(:call).and_return({ kunten: "複雑漢文", kakikudashi: "複雑なり" })
    end

    it "fallback: true になる" do
      expect(result.fallback).to eq true
    end

    it "骨格がnilのままLLM全文委譲プロンプトが使われる" do
      expect_any_instance_of(described_class)
        .to receive(:call_ollama)
        .with(include("現代日本語を漢文"))
      described_class.call("私は林檎を食べる")
    end
  end
end

