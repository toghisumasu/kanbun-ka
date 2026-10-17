require "rails_helper"

# LLM が白文でない出力（仮名混じり）を返したときの作り直しを確かめる。
RSpec.describe KanbunTranslatorService do
  before do
    allow_any_instance_of(described_class).to receive(:run_mecab).and_return("EOS\n")
    allow(MeCabAdapter).to receive(:call).and_return([])
    allow_any_instance_of(KanbunBNFParser).to receive(:parse).and_return(nil)
  end

  def stub_ollama(*responses)
    allow_any_instance_of(described_class).to receive(:call_ollama).and_return(*responses)
  end

  describe "白文の形の判定" do
    it "漢字と句読点だけなら白文" do
      expect("私不読漢文。").to match(described_class::HAKUBUN_PATTERN)
    end

    it "仮名や空白が混じれば白文ではない" do
      expect("学ぶことは楽しゅう。").not_to match(described_class::HAKUBUN_PATTERN)
      expect("私 食 林檎").not_to match(described_class::HAKUBUN_PATTERN)
    end
  end

  describe "再試行" do
    it "仮名混じりの出力は 1 回だけ作り直し、直ればそれを使う" do
      stub_ollama("花が咲き鳥が鳴く。", "花開鳥啼")
      result = described_class.call("花が咲き鳥が鳴く")
      expect(result.retried).to eq true
      expect(result.hakubun).to eq "花開鳥啼"
      expect(result.parse_error).to be_nil
    end

    it "作り直しても直らなければ 2 回目の出力を使い、再試行は 1 回で止める" do
      stub_ollama("人の皆は死ぬ。", "人の皆死ぬ")
      result = described_class.call("人は皆死ぬ")
      expect(result.retried).to eq true
      expect(result.hakubun).to eq "人の皆死ぬ"
      expect(result.parse_error).not_to be_nil
    end

    it "最初から白文なら作り直さない" do
      stub_ollama("私不読漢文")
      result = described_class.call("私は漢文を読まない")
      expect(result.retried).to eq false
      expect(result.kunten).to eq "私不[レ]読[二]漢文[一]"
    end

    it "空白と 2 行目以降は取り除く" do
      stub_ollama("私 不 読 漢 文\n（説明）")
      result = described_class.call("私は漢文を読まない")
      expect(result.hakubun).to eq "私不読漢文"
      expect(result.retried).to eq false
    end
  end
end
