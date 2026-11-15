require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/yomi").to_s

# Phase 6a 第2段 S8: 直書きされた機能語の読みも used_entries に FUNC:<字> として記録する。
#   role で読みが分かれる字は FUNC:<字>@<role>、置字の乎は FUNC:乎@silent。
RSpec.describe "Yomi::Result#used_entries の FUNC" do
  def used(hakubun)
    Kanbun::Yomi.analyze(KanbunParser.new.parse_tree(hakubun, strict: true)).used_entries
  end

  def self.func_cases(rows)
    rows.each do |hakubun, ids|
      it "#{hakubun}: #{ids.join(' ')}" do
        expect(used(hakubun)).to include(*ids)
      end
    end
  end

  describe "文中の機能語" do
    func_cases [
      ["不学", %w[FUNC:不 VERBS:学]],
      ["無水", %w[FUNC:無]],
      ["勿待人", %w[FUNC:勿]],
      ["彼非君子也", %w[FUNC:非 FUNC:也]],
      ["学而不行", %w[FUNC:而 FUNC:不]],
      ["入於深林焉", %w[FUNC:於 FUNC:焉]],
      ["花開于山", %w[FUNC:于]],
      ["学哉", %w[FUNC:哉]],
      ["学邪", %w[FUNC:邪]],
      ["若学則楽", %w[FUNC:若 FUNC:則]],
      ["不可不行", %w[FUNC:可@dneg FUNC:不@dneg]],
      ["不得不知", %w[FUNC:得@dneg FUNC:不@dneg]],
      ["王使臣行", %w[FUNC:使]],
      ["彼被殺", %w[FUNC:被]],
      ["与友飲酒", %w[FUNC:与]],
      ["彼自鹿児島来", %w[FUNC:自]],
      ["其疾如風", %w[FUNC:其 FUNC:如@hikyo]],
      ["無所知", %w[FUNC:無 FUNC:所]]
    ]
  end

  describe "同じ字でも読みの出どころが違うもの" do
    func_cases [
      ["学乎", %w[FUNC:乎]],
      ["入乎深林", %w[FUNC:乎@silent]],
      ["彼為敵所殺", %w[FUNC:為@ukemi FUNC:所]],
      ["見殺", %w[FUNC:見@ukemi_mi]],
      ["人莫若友", %w[FUNC:莫@compare_neg FUNC:若@compare]],
      ["人不如友", %w[FUNC:不@compare_neg FUNC:如@compare]],
      ["非徒無益", %w[FUNC:非@ruika_neg FUNC:徒@ruika_adv]],
      ["非徒無益而又害之", %w[FUNC:而@ruika_ji]]
    ]

    it "乎（疑問）と 乎（置字）は別の項目" do
      expect(used("学乎")).not_to include("FUNC:乎@silent")
      expect(used("入乎深林")).not_to include("FUNC:乎")
    end
  end

  describe "主題の「は」を直書きで付ける箇所" do
    func_cases [
      ["我読漢文", %w[FUNC:主題は]]
    ]
  end

  it "名詞だけの文は FUNC を持たない（名詞は対象外）" do
    expect(used("深林").grep(/\AFUNC:/)).to eq []
    expect(used("孔子聖人").grep(/\AFUNC:/)).to eq [] # 名詞述語の「なり」は FUNC にならない（RULE:verb_phrase/NOUN NOUN で扱う。第2段 S9）
  end

  it "FUNC の項目 ID も重複しない" do
    ids = used("不学而不行")
    expect(ids).to eq ids.uniq
  end
end
