require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s

RSpec.describe Kanbun::Lexicon do
  # 意図して複数品詞に登録している表層形（増やすときはここに理由を書く）
  let(:intended_overlaps) { %w[言] } # 言: VERB（言う）と NOUN（ことば）。VERB 優先

  it "意図しない重複登録がない" do
    expect(Kanbun::Lexicon.overlaps).to eq intended_overlaps
  end

  it "全トークンが文法（token 宣言）に存在する" do
    known = KanbunParser::Racc_token_to_s_table
    missing = Kanbun::Lexicon::TABLE.values.uniq.reject { |t| known.include?(t.to_s) }
    expect(missing).to be_empty
  end

  it "複数字語は PATTERN で長い順に先に当たる" do
    expect("深林"[Kanbun::Lexicon::PATTERN]).to eq "深林"
    expect("不亦"[Kanbun::Lexicon::PATTERN]).to eq "不亦"
  end

  it "言 は VERB に解決される" do
    expect(Kanbun::Lexicon::TABLE["言"]).to eq :VERB
  end
end
