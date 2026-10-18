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
end
