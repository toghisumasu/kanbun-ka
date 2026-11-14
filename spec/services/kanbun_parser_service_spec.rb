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

    def interim_of(result)
      Kanbun::Kakikudashi.convert(result[:kunten_aozora], yomi: false, hiragana: true)
    end

    describe "曖昧な受身は暫定出力（漢字を読み順に並べたもの）に戻す（Phase 5b S7）" do
      %w[殺於敵 為敵殺 学於人].each do |hakubun|
        it "#{hakubun}: 暫定出力・exact:false・理由つき（止めない）" do
          result = described_class.call(hakubun)
          expect(result[:status]).to eq :parsed
          expect(result[:kakikudashi_exact]).to be false
          expect(result[:kakikudashi_reasons]).to include(a_string_matching(/受身か(能動|連動)か決まりません/))
          expect(result[:kakikudashi]).to eq interim_of(result)
          expect(result[:kakikudashi]).not_to match(/[ぁ-ん]/) # 助詞・活用を付けた読みを返さない
        end
      end

      it "確定した受身（為A所B・見V・被V於A）は書き下しのまま exact:true" do
        { "彼為敵所殺" => "彼は敵の殺す所と為る", "見殺" => "殺さる", "被殺於敵" => nil }.each do |hakubun, expected|
          result = described_class.call(hakubun)
          expect(result[:kakikudashi_exact]).to be(true), hakubun
          expect(result[:kakikudashi_reasons]).to eq([]), hakubun
          expect(result[:kakikudashi]).not_to eq(interim_of(result)), hakubun
          expect(result[:kakikudashi]).to eq(expected) if expected
        end
      end
    end

    describe "exact は 復文検査（Kanbun::Fukubun）の結果で決まる（Phase 5b S3）" do
      let(:broken) { Kanbun::Yomi::Result.new("我は読む", []) } # 漢文 が欠落した書き下し

      it "Yomi が確信していても、復文検査に違反があれば exact にしない" do
        allow(Kanbun::Yomi).to receive(:analyze).and_return(broken)
        result = described_class.call("我読漢文")
        expect(result[:status]).to eq :parsed
        expect(result[:kakikudashi_exact]).to be false
        expect(result[:kakikudashi_reasons]).to include("字の欠落: 漢", "字の欠落: 文")
      end

      it "違反があれば暫定の書き下し（漢字を読み順に並べたもの）に戻す" do
        allow(Kanbun::Yomi).to receive(:analyze).and_return(broken)
        expect(described_class.call("我読漢文")[:kakikudashi]).to eq "我漢文読"
      end

      it "違反がなく Yomi が確信していれば exact（検査の結果が理由なしで通る）" do
        result = described_class.call("我読漢文")
        expect(result[:kakikudashi_exact]).to be true
        expect(result[:kakikudashi_reasons]).to eq []
        tree = KanbunParser.new.parse_tree("我読漢文", strict: true)
        expect(Kanbun::Fukubun.check(tree, result[:kakikudashi])).to eq []
      end

      it "Yomi が曖昧と申告したときは、検査に通っても exact にせず、暫定出力と理由を返す" do
        result = described_class.call("殺於敵")
        expect(result[:kakikudashi_exact]).to be false
        expect(result[:kakikudashi_reasons]).to include(a_string_matching(/受身か能動か/))
        expect(result[:kakikudashi]).to eq "敵殺"
      end
    end

    it "確かに読める句は exact で、理由は空" do
      result = described_class.call("我読漢文")
      expect(result[:kakikudashi_exact]).to be true
      expect(result[:kakikudashi_reasons]).to eq []
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
