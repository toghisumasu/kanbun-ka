require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/yomi").to_s
require Rails.root.join("script/gen_rule_ids").to_s

# Phase 6a 第2段 S9: 木を組んだ文法規則も used_entries に RULE:<規則名> として記録する。
# 規則名は「左辺/右辺の記号」。.y は変えず、生成された各 _reduce_N を包んで節点に規則名を付ける。
RSpec.describe "Yomi::Result#used_entries の RULE" do
  def tree(hakubun) = KanbunParser.new.parse_tree(hakubun, strict: true)

  def used(hakubun)
    Kanbun::Yomi.analyze(tree(hakubun)).used_entries
  end

  describe "規則名の表（lib/kanbun/rule_ids.rb）" do
    it ".y から作り直した表と一致する（.y を変えたら script/gen_rule_ids.rb で作り直す）" do
      expect(Kanbun::RuleIds::TABLE).to eq GenRuleIds.parse.to_h { |n, name, comment| [n, [name, comment]] }
    end

    it "Racc が生成した _reduce_N の数と一致する" do
      reduces = KanbunParser.instance_methods(false).grep(/\A_reduce_\d+\z/).size
      expect(Kanbun::RuleIds::TABLE.size).to eq reduces
    end

    it "規則名は重複しない（名前から規則が 1 つに決まる）" do
      names = Kanbun::RuleIds::TABLE.values.map(&:first)
      expect(names).to eq names.uniq
    end
  end

  describe "木の節点に規則名が付く" do
    it "根の節点に、その節点を作った規則の名前が付く" do
      expect(tree("我読漢文").rule).to eq "verb_phrase/NOUN pred_tr"
      expect(tree("不学").rule).to eq "neg_clause/NEG_BU verb_phrase"
    end

    it "通過だけの規則（clause: neg_clause など）は節点の規則名を上書きしない" do
      expect(tree("不学").rule).not_to start_with("clause/")
    end
  end

  describe "used_entries に RULE を入れる" do
    it "我読漢文: 使った規則（文を組む規則と述語の規則）" do
      expect(used("我読漢文")).to include("RULE:verb_phrase/NOUN pred_tr", "RULE:pred_obj/VERB NOUN")
      expect(used("我読漢文")).not_to include("RULE:verb_phrase/NOUN NOUN")
    end

    it "孔子聖人（名詞述語）は verb_phrase/NOUN NOUN" do
      expect(used("孔子聖人")).to eq ["RULE:verb_phrase/NOUN NOUN"]
    end

    it "同じ Seq(Leaf, Leaf) の形でも、主述（犬走）は別の規則" do
      expect(used("犬走")).to include("RULE:sv/NOUN pred_in")
      expect(used("犬走")).not_to include("RULE:verb_phrase/NOUN NOUN")
    end

    it "無非王土: 二重否定の規則と、王土を 王＋土 に切った名詞述語の規則の両方" do
      expect(used("無非王土")).to include("RULE:double_neg_clause/NEG_MU NEG_HI verb_phrase", "RULE:verb_phrase/NOUN NOUN")
    end

    it "学与: 疑問の与の規則" do
      expect(used("学与")).to include("RULE:shitsumon_clause/verb_phrase YO_NIMO")
    end

    it "規則 ID は重複しない" do
      ids = used("不学而不行")
      expect(ids).to eq ids.uniq
    end

    it "規則名のない木（手で組んだ木）では RULE を記録しない" do
      leaf = Kanbun::Tree::Leaf.new("学")
      expect(Kanbun::Yomi.analyze(leaf).used_entries.grep(/\ARULE:/)).to eq []
    end
  end

  describe "解析の結果は変わらない" do
    it "規則名の記録は、返り点・書き下しを変えない" do
      expect(Kanbun::Yomi.kakikudashi(tree("我読漢文"))).to eq "我は漢文を読む"
      expect(tree("不学").to_s).to eq "不学"
    end
  end
end
