require "rails_helper"

# LLM の出力を白文の形に整える normalize（繁体字を日本の字体へ、1 行目だけ、空白を除く）。
RSpec.describe KanbunTranslatorService do
  def normalize(raw)
    KanbunTranslatorService.new("x").send(:normalize, raw)
  end

  it "繁体字を日本の字体に直す" do
    expect(normalize("先生教學生")).to eq "先生教学生"
    expect(normalize("國興國滅")).to eq "国興国滅"
  end

  it "簡体字・繁体字（樂・歸・冰・处）も直す" do
    expect(normalize("不亦樂乎")).to eq "不亦楽乎"
    expect(normalize("老人歸山")).to eq "老人帰山"
    expect(normalize("冰莫如水冷")).to eq "氷莫如水冷"
    expect(normalize("勿笑此处")).to eq "勿笑此処"
  end

  it "空白を除き、最初の 1 行だけ取る" do
    expect(normalize("彼 不 読書\n説明文")).to eq "彼不読書"
  end

  it "文字列でなければそのまま返す" do
    expect(normalize(nil)).to be_nil
  end

  describe "drop_stray_question_marker（Phase 4t）" do
    def drop(input, hakubun, skeleton)
      KanbunTranslatorService.new(input).send(:drop_stray_question_marker, hakubun, skeleton)
    end

    it "疑問でない文に混じった乎を除く" do
      expect(drop("学ばなければ道を知らない", "不学則不知乎道", "不 学ぶ 則 不 知る 道")).to eq "不学則不知道"
    end

    it "骨格に乎があれば残す" do
      expect(drop("君は学ぶか", "君学乎", "君 学ぶ 乎")).to eq "君学乎"
    end

    it "原文に か があれば残す" do
      expect(drop("楽しくないか", "不亦楽乎", "不 楽しい")).to eq "不亦楽乎"
    end

    it "骨格がなければそのまま" do
      expect(drop("山は雲より高い", "山高於乎雲", nil)).to eq "山高於乎雲"
    end
  end
end
