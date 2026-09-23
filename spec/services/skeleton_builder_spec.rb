require "rails_helper"

RSpec.describe SkeletonBuilder do
  def tok(surface, pos_type, base_form = nil)
    KanbunBNFParser::Token.new(
      surface: surface, pos_type: pos_type, base_form: base_form || surface
    )
  end

  def build(tokens)
    result = KanbunBNFParser.new(tokens).parse
    described_class.call(result)
  end

  describe "動詞文" do
    it "他動詞: 私は林檎を食べる" do
      tokens = [tok("私",:pron,"私"), tok("は",:wa), tok("林檎",:noun),
                tok("を",:wo), tok("食べ",:verb,"食べる")]
      expect(build(tokens)).to eq "私 食べる 林檎"
    end

    it "否定: 私は林檎を食べない" do
      tokens = [tok("私",:pron,"私"), tok("は",:wa), tok("林檎",:noun),
                tok("を",:wo), tok("食べ",:verb,"食べる"), tok("ない",:neg)]
      expect(build(tokens)).to eq "私 不 食べる 林檎"
    end

    it "自動詞: 犬が走る" do
      tokens = [tok("犬",:noun), tok("が",:ga), tok("走る",:verb)]
      expect(build(tokens)).to eq "犬 走る"
    end

    it "使役: 王は人を行かせた → 使構文・矣" do
      tokens = [tok("王",:noun), tok("は",:wa), tok("人",:noun), tok("を",:wo),
                tok("行か",:verb,"行く"), tok("せ",:causative), tok("た",:past)]
      expect(build(tokens)).to eq "王 使 人 行く 矣"
    end

    it "受身: 王が臣下に殺された → 被構文・於・矣" do
      tokens = [tok("王",:noun), tok("が",:ga), tok("臣下",:noun), tok("に",:ni),
                tok("殺さ",:verb,"殺す"), tok("れ",:passive), tok("た",:past)]
      expect(build(tokens)).to eq "王 被 殺す 於 臣下 矣"
    end
  end

  describe "存在文" do
    it "足がない → 無構文" do
      tokens = [tok("足",:noun), tok("が",:ga), tok("ない",:nai_adj)]
      expect(build(tokens)).to eq "無 足"
    end

    it "蛇に足がある → 有構文・於" do
      tokens = [tok("蛇",:noun), tok("に",:ni), tok("足",:noun),
                tok("が",:ga), tok("ある",:aru)]
      expect(build(tokens)).to eq "有 足 於 蛇"
    end
  end

  describe "形容詞文" do
    it "馬は速い" do
      tokens = [tok("馬",:noun), tok("は",:wa), tok("速い",:adj)]
      expect(build(tokens)).to eq "馬 速い"
    end

    it "否定: 馬は速くない → 不" do
      tokens = [tok("馬",:noun), tok("は",:wa), tok("速い",:adj), tok("ない",:neg)]
      expect(build(tokens)).to eq "馬 不 速い"
    end
  end

  describe "連動文" do
    it "王は民を集めて号令した → 動詞列・矣" do
      tokens = [tok("王",:noun), tok("は",:wa), tok("民",:noun), tok("を",:wo),
                tok("集め",:verb,"集める"), tok("て",:conj_te),
                tok("号令し",:verb,"号令する"), tok("た",:past)]
      expect(build(tokens)).to eq "王 集める 号令する 民 矣"
    end
  end

  describe "比較文" do
    it "馬は牛より速い → 莫如" do
      tokens = [tok("馬",:noun), tok("は",:wa), tok("牛",:noun),
                tok("より",:yori), tok("速い",:adj)]
      expect(build(tokens)).to eq "馬 莫如 牛 速い"
    end

    it "地は人より優れない → 不若" do
      tokens = [tok("地",:noun), tok("は",:wa), tok("人",:noun),
                tok("より",:yori), tok("優れ",:verb,"優れる"), tok("ない",:neg)]
      expect(build(tokens)).to eq "地 不若 人 優れる"
    end
  end

  describe "疑問文" do
    it "汝は勇を好むか → 乎（矣より優先）" do
      tokens = [tok("汝",:pron,"汝"), tok("は",:wa), tok("勇",:noun),
                tok("を",:wo), tok("好む",:verb), tok("か",:question)]
      expect(build(tokens)).to eq "汝 好む 勇 乎"
    end
  end
end

