# frozen_string_literal: true

require_relative '../../support/kanbun_fixtures'
require_relative '../../../lib/kanbun/kakikudashi'

RSpec.describe Kanbun::Aozora do
  def parse(text) = described_class.parse(text)

  describe '.parse' do
    it '送り仮名・返り点を読み取る' do
      u = parse('請フ［＃レ］').first
      expect(u.kanji).to eq '請'
      expect(u.okuri).to eq 'フ'
      expect(u.kunten).to eq 'レ'
      expect(u.yomi).to be_nil
      expect(u.saidoku).to be_nil
    end

    it '表示読み《》と非表示読み〈〉を区別する' do
      shown, hidden = parse('易《か》ヘ使〈シ〉')
      expect(shown.yomi.text).to eq 'か'
      expect(shown.yomi).not_to be_hidden
      expect(hidden.yomi.text).to eq 'シ'
      expect(hidden.yomi).to be_hidden
    end

    it '置き字は空の〈〉で表す' do
      u = parse('矣〈〉').first
      expect(u.yomi).to be_hidden
      expect(u.yomi.text).to eq ''
    end

    it '再読文字の二度目の読みと送り仮名を読み取る' do
      u = parse('未《いま》ダ〈ざ〉ル［＃レ］').first
      expect(u.yomi.text).to eq 'いま'
      expect(u.okuri).to eq 'ダ'
      expect(u.saidoku.text).to eq 'ざ'
      expect(u.saidoku).to be_hidden
      expect(u.saidoku_okuri).to eq 'ル'
      expect(u.kunten).to eq 'レ'
    end

    it '最初の読みがない再読文字（〈〉のみ）を読み取る' do
      u = parse('不〈〉〈ズ〉［＃乙］').first
      expect(u.yomi.text).to eq ''
      expect(u.saidoku.text).to eq 'ズ'
      expect(u.kunten).to eq '乙'
    end

    it '送り仮名の［＃（…）］記法を読み取る' do
      u = parse('盍《なん》［＃（ゾ）］〈ザ〉［＃（ル）］［＃レ］').first
      expect(u.okuri).to eq 'ゾ'
      expect(u.saidoku_okuri).to eq 'ル'
      expect(u.kunten).to eq 'レ'
    end

    it '一レ・甲レ の複合返り点を 1 つの kunten として読む' do
      expect(parse('有ルガ［＃一レ］').first.kunten).to eq '一レ'
      expect(parse('乱サ［＃甲レ］').first.kunten).to eq '甲レ'
      expect(parse('有ルガ［＃一レ］').first.order_mark).to eq '一'
    end

    it '句読点を 1 単位として読む' do
      expect(parse('王、').map(&:kanji)).to eq %w[王 、]
    end

    it '竪点を読み取る（U+2010 と ASCII ハイフン）' do
      expect(parse("如‐何").first).to be_tate
      expect(parse('如-何').first).to be_tate
    end

    it '異体字選択子付きの漢字と拡張漢字を 1 字として読む' do
      expect(parse("葛\u{E0100}ヲ").first.kanji).to eq "葛\u{E0100}"
      expect(parse('𠮟ル').first.kanji).to eq '𠮟'
    end

    it '改行は無視する' do
      expect(parse("王\n、").map(&:kanji)).to eq %w[王 、]
    end

    it '漢字でない文字から始まると ParseError（位置を含む）' do
      expect { parse('王ABC') }.to raise_error(described_class::ParseError, /2 文字目/)
    end
  end

  describe '.hakubun' do
    KanbunFixtures::CASES.each do |c|
      it "#{c[:name]} の白文を取り出す" do
        expect(described_class.hakubun(c[:text])).to eq c[:hakubun]
      end
    end
  end
end

RSpec.describe Kanbun::Reorder do
  describe '.reorder' do
    it '竪点は次の字を後ろに連結する' do
      kanji = described_class.reorder(Kanbun::Aozora.parse("如‐何")).map(&:kanji)
      expect(kanji).to eq %w[如 何]
    end

    KanbunFixtures::UNRESOLVED.each do |name, text|
      it "未解決の返り点（#{name}）は黙って捨てず Error にする" do
        expect { described_class.reorder(Kanbun::Aozora.parse(text)) }
          .to raise_error(described_class::Error)
      end
    end
  end
end

RSpec.describe '白雲期（白居易）' do
  let(:lines) { KanbunFixtures.hakuunki_lines }

  it '白文（句読点なし）が原文と一致する' do
    hakubun = lines.map { |l| Kanbun::Aozora.hakubun(l, punctuation: false) }.join
    expect(hakubun).to eq KanbunFixtures::HAKUUNKI_ORIGINAL
  end

  KanbunFixtures::HAKUUNKI_KAKI.each_with_index do |kaki, i|
    it "#{i + 1} 対句の書き下し（草稿）" do
      expect(Kanbun::Kakikudashi.convert(lines[i], yomi: false)).to eq kaki
    end
  end
end

RSpec.describe Kanbun::Kakikudashi do
  KanbunFixtures::CASES.each do |c|
    describe c[:name] do
      it '書き下し（読み非表示・カタカナ）' do
        expect(described_class.convert(c[:text], yomi: false)).to eq c[:kaki]
      end

      it '書き下し（読み表示）' do
        expect(described_class.convert(c[:text], yomi: true)).to eq c[:kaki_yomi]
      end

      it '書き下し（平仮名）' do
        expect(described_class.convert(c[:text], yomi: false, hiragana: true)).to eq c[:kaki_hira]
      end
    end
  end
end
