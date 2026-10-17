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

    it "書き下しは返り点の順に並べる（送り仮名は未付与）" do
      expect(described_class.call("我読漢文")[:kakikudashi]).to eq "我漢文読"
    end

    it "再読文字は 2 度読む" do
      expect(described_class.call("未知")[:kakikudashi]).to eq "未だ知ず"
    end

    it "前後の空白は無視する" do
      expect(described_class.call(" 不学\n")[:kunten]).to eq "不[レ]学"
    end
  end

  describe "解析できない白文" do
    it "辞書にない字を含むときは白文をそのまま返し、理由を添える" do
      result = described_class.call("我食林檎")
      expect(result[:status]).to eq :unparsed
      expect(result[:kunten]).to eq "我食林檎"
      expect(result[:kakikudashi]).to eq "我食林檎"
      expect(result[:error]).to include("UnknownCharacters")
      expect(result[:error]).to include("林檎")
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
