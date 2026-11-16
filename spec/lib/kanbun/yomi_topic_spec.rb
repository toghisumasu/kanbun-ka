require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/yomi").to_s

# Phase 6a: 単独の代名詞には主題の「は」を付けない（28 文の照合 #6）。
# 送り仮名は文意に即して付く。単独では付かない。
RSpec.describe "主題の「は」：単独の代名詞" do
  def yomi(hakubun)
    Kanbun::Yomi.kakikudashi(KanbunParser.new.parse_tree(hakubun, strict: true))
  end

  def used(hakubun)
    Kanbun::Yomi.analyze(KanbunParser.new.parse_tree(hakubun, strict: true)).used_entries
  end

  %w[我 吾 汝 彼 私 此 是].each do |p|
    it "単独の #{p} は #{p} のまま（「は」を付けない・FUNC:主題は も使わない）" do
      expect(yomi(p)).to eq p
      expect(used(p)).not_to include("FUNC:主題は")
    end
  end

  it "述語が続く文の代名詞には従来どおり「は」を付ける" do
    expect(yomi("我読漢文")).to eq "我は漢文を読む"
    expect(yomi("彼非君子")).to eq "彼は君子に非ず"
  end
end
