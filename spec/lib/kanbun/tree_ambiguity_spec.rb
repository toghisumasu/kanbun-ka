require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/kunten").to_s
require Rails.root.join("lib/kanbun/yomi").to_s

# Phase 5b S1: 読みが決まらない構文には、パーサーが構文木に ambiguous（理由）を付ける。
# Yomi は ambiguous な木を exact とは名乗らない。受身が確定している形は ambiguous にしない。
RSpec.describe "構文木の ambiguous" do
  def tree(hakubun) = KanbunParser.new.parse_tree(hakubun, strict: true)

  def reasons(hakubun) = Kanbun::Tree.ambiguities(tree(hakubun))

  describe "曖昧な受身" do
    it "殺於敵（他動詞＋於A）は、受身か能動か決まらない" do
      expect(reasons("殺於敵")).to include(a_string_matching(/受身か能動か/))
    end

    it "為敵殺（所なしの 為A V）は、受身か連動か決まらない" do
      expect(reasons("為敵殺")).to include(a_string_matching(/為A V/))
    end

    it "主語がついても ambiguous は残る（彼殺於賊・彼為敵殺）" do
      expect(reasons("彼殺於賊")).not_to be_empty
      expect(reasons("彼為敵殺")).not_to be_empty
    end
  end

  describe "受身が確定している形・曖昧でない形は ambiguous にしない" do
    %w[見殺 被殺 彼被殺 王被殺於臣下矣 為敵所殺 彼為敵所殺 兄釣魚於海 問礼於老子 氷冷於水
       我読漢文 寧為無為 何為行 入於深林 登於山].each do |hakubun|
      it "#{hakubun} は ambiguous なし" do
        expect(reasons(hakubun)).to be_empty
      end
    end
  end

  describe "Yomi の exact" do
    def exact?(hakubun) = Kanbun::Yomi.analyze(tree(hakubun)).exact?

    it "曖昧な 殺於敵・為敵殺 は exact でない" do
      expect(exact?("殺於敵")).to be false
      expect(exact?("為敵殺")).to be false
    end

    it "確定した受身（見殺・被殺・為A所B）は exact のまま" do
      expect(exact?("見殺")).to be true
      expect(exact?("被殺")).to be true
      expect(exact?("彼為敵所殺")).to be true
    end
  end
end
