require "rails_helper"
require Rails.root.join("lib/kanbun/usage_ranking").to_s

# Phase 6a 第2段 S11: 未確認項目の使用頻度を、種類（辞書・FUNC・RULE・DEFAULT）ごとの上位 N に分ける。
RSpec.describe Kanbun::UsageRanking do
  let(:usage) do
    { "VERBS:学" => 5, "ADJS:賢" => 2, "FUNC:不" => 9, "FUNC:也" => 1, "RULE:neg_clause/NEG_BU verb_phrase" => 7,
      "RULE:verb_phrase/NOUN NOUN" => 3, "DEFAULT:particle:読" => 4 }
  end

  it "種類ごとに分ける（辞書・FUNC・RULE・DEFAULT の順）" do
    expect(described_class.sections(usage).map(&:first)).to eq %w[辞書の表 FUNC（直書きの機能語） RULE（文法規則） DEFAULT（既定値）]
  end

  it "各種類の中は使用数の多い順（同数は ID 順）" do
    sections = described_class.sections(usage).to_h
    expect(sections["FUNC（直書きの機能語）"]).to eq [["FUNC:不", 9], ["FUNC:也", 1]]
    expect(sections["辞書の表"]).to eq [["VERBS:学", 5], ["ADJS:賢", 2]]
  end

  it "上位 N 件に絞る" do
    expect(described_class.sections(usage, top: 1).to_h["RULE（文法規則）"]).to eq [["RULE:neg_clause/NEG_BU verb_phrase", 7]]
  end

  it "項目がない種類は空配列で残す" do
    expect(described_class.sections({ "FUNC:不" => 1 }).to_h["RULE（文法規則）"]).to eq []
  end

  it "表示用の行にする" do
    expect(described_class.lines({ "FUNC:不" => 3 }, top: 5)).to include("FUNC（直書きの機能語）", "     3  FUNC:不")
  end
end
