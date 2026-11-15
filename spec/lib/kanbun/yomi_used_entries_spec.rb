require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/yomi").to_s

# Phase 6a S2: Yomi::Result#used_entries（読みを作るのに使った辞書項目の ID）。
# ID は「表名:キー」。既定値で読みを補ったときは「DEFAULT:種類:字」。名詞は対象外。
RSpec.describe "Yomi::Result#used_entries" do
  def used(hakubun)
    tree = KanbunParser.new.parse_tree(hakubun, strict: true)
    Kanbun::Yomi.analyze(tree).used_entries
  end

  it "動詞は VERBS:字 を記録する" do
    expect(used("我読漢文")).to include("VERBS:読")
  end

  it "形容詞は ADJS:字、副詞は ADVS:字 を記録する" do
    expect(used("苛政猛於虎")).to include("ADJS:猛")
    expect(used("人皆死")).to include("ADVS:皆", "VERBS:死")
  end

  it "全体の読みを持つ副詞は ADV_WHOLE:字 を記録する（ADVS は記録しない）" do
    ids = used("故郷何独在長安")
    expect(ids).to include("ADV_WHOLE:何独")
    expect(ids).not_to include("ADVS:何独")
  end

  it "再読文字は 1 度目の読み SAIDOKU:字 と 2 度目の読み SAIDOKU_SECOND:字 を記録する" do
    expect(used("未知")).to include("SAIDOKU:未", "SAIDOKU_SECOND:未", "VERBS:知")
  end

  it "名詞（我・漢文・故郷）は項目にならない" do
    expect(used("我読漢文").grep(/我|漢文/)).to be_empty
    expect(used("故郷何独在長安").grep(/故郷|長安/)).to be_empty
  end

  it "項目 ID は重複しない" do
    ids = used("未知故郷事")
    expect(ids).to eq ids.uniq
  end

  describe "既定値で補った読みは DEFAULT:種類:字 を記録する" do
    it "助詞：動詞が目的語の助詞を明示していないとき（読 は obj の指定なし）" do
      expect(used("我読漢文")).to include("DEFAULT:particle:読")
    end

    it "助詞：補語の助詞を明示していないとき（学於人 の 学）" do
      expect(used("学於人")).to include("DEFAULT:particle:学")
    end

    it "助詞を明示した動詞（入 は obj: に）で、その助詞を使った文には DEFAULT を記録しない" do
      expect(used("返景入深林").grep(/DEFAULT:particle:入/)).to be_empty
    end

    it "助詞：名詞に助詞を付けない動詞（名詞なしの 学）では DEFAULT を記録しない" do
      expect(used("不学").grep(/DEFAULT/)).to be_empty
    end

    it "活用形：直前の語が形を要求しないとき（demand に form がない）" do
      tree = KanbunParser.new.parse_tree("学", strict: true)
      items = Kanbun::Yomi.collect(tree)
      _, ids = Kanbun::Yomi.collecting { Kanbun::Yomi.conjugate_verb(items, 0, {}) }
      expect(ids).to include("VERBS:学", "DEFAULT:form:学")
    end

    it "活用形：文末の終止形（demand に form: :shushi がある）は既定値ではない" do
      expect(used("不学").grep(/DEFAULT:form/)).to be_empty
      expect(used("人皆死").grep(/DEFAULT:form/)).to be_empty
    end
  end

  it "Result は used_entries を省略しても作れる（既存の呼び出し互換）" do
    expect(Kanbun::Yomi::Result.new("我は読む", []).used_entries).to be_nil
  end
end
