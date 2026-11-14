require "rails_helper"

RSpec.describe KanbunParserService do
  describe "解析できる白文" do
    it "訓点付き漢文（返り点）を返す" do
      result = described_class.call("我読漢文")
      expect(result[:kunten]).to eq "我読[二]漢文[一]"
      expect(result[:status]).to eq :parsed
      expect(result[:error]).to be_nil
    end

    it "レ点・一二三点も付く" do
      expect(described_class.call("不読書")[:kunten]).to eq "不[レ]読[レ]書"
      expect(described_class.call("不必読漢文")[:kunten]).to eq "不[三]必読[二]漢文[一]"
    end

    it "注記つき漢文（正本）を返す" do
      expect(described_class.call("我読漢文")[:kunten_aozora]).to eq "我読［＃二］漢文［＃一］"
    end

    it "書き下しは読み辞書と活用で作る（歴史的仮名遣い）" do
      result = described_class.call("我読漢文")
      expect(result[:kakikudashi]).to eq "我は漢文を読む"
      expect(result[:kakikudashi_exact]).to be true
    end

    it "再読文字は 2 度読む" do
      expect(described_class.call("未知")[:kakikudashi]).to eq "未だ知らず"
    end

    it "曖昧な句形（殺於敵・為敵殺）は書き下しを返すが exact にせず、理由を添える。見V は確定した受身なので exact" do
      expect(described_class.call("見殺")[:kakikudashi_exact]).to be true
      %w[殺於敵 為敵殺].each do |hakubun|
        result = described_class.call(hakubun)
        expect(result[:status]).to eq(:parsed), hakubun
        expect(result[:kakikudashi_exact]).to be(false), hakubun
        expect(result[:kakikudashi_notes]).not_to be_empty, hakubun
        expect(result[:kakikudashi]).not_to eq(hakubun), hakubun
      end
    end

    it "確かに読める句は exact で、理由は空" do
      result = described_class.call("我読漢文")
      expect(result[:kakikudashi_exact]).to be true
      expect(result[:kakikudashi_notes]).to eq []
    end

    it "読みの辞書にない語を含むときは、暫定の書き下し（漢字を読み順に並べたもの）に戻し、exact を false にする" do
      result = described_class.call("寧為無為")
      expect(result[:status]).to eq :parsed
      expect(result[:kakikudashi_exact]).to be false
      expect(result[:kakikudashi]).to eq "寧為為無"
    end

    it "前後の空白は無視する" do
      expect(described_class.call(" 不学\n")[:kunten]).to eq "不[レ]学"
    end
  end

  describe "解析できない白文" do
    it "辞書にない字を含むときは白文をそのまま返し、理由を添える" do
      result = described_class.call("我食蜜柑")
      expect(result[:status]).to eq :unparsed
      expect(result[:kunten]).to eq "我食蜜柑"
      expect(result[:kakikudashi]).to eq "我食蜜柑"
      expect(result[:error]).to include("UnknownCharacters")
      expect(result[:error]).to include("蜜柑")
    end

    it "文法外の語順のときも例外にしない" do
      result = described_class.call("花開鳥")
      expect(result[:status]).to eq :unparsed
      expect(result[:kunten]).to eq "花開鳥"
      expect(result[:error]).to include("ParseError")
    end

    it "空文字でも例外にしない" do
      expect(described_class.call("")[:status]).to eq :unparsed
    end
  end
end
