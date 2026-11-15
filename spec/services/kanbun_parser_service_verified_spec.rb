require "rails_helper"

# Phase 6a S4: kakikudashi_exact = tree_ok（従来の exact）かつ verified（使った辞書項目がすべて確認済み）。
# 確認済みの一覧はダミーを注入する（本番の一覧は空）。
RSpec.describe KanbunParserService, "確認済み印（Phase 6a）" do
  def stub_verified(table_keys)
    allow(described_class).to receive(:verified_entries).and_return(Kanbun::VerifiedEntries.new(table_keys))
  end

  describe "一覧が空（本番の初期状態）" do
    it "従来どおり読めた文でも exact:false。tree_ok は true、verified は false" do
      r = described_class.call("我読漢文")
      expect(r[:kakikudashi_tree_ok]).to be true
      expect(r[:kakikudashi_verified]).to be false
      expect(r[:kakikudashi_exact]).to be false
    end

    it "書き下しは Yomi の読みのまま返す（暫定の漢字列に戻さない）" do
      expect(described_class.call("我読漢文")[:kakikudashi]).to eq "我は漢文を読む"
    end

    it "理由に、未確認の項目と既定値を根拠つきで出す" do
      reasons = described_class.call("我読漢文")[:kakikudashi_reasons]
      expect(reasons).to include("未確認の辞書項目: VERBS:読")
      expect(reasons).to include(a_string_matching(/\A既定値: 助詞（読）/))
    end

    it "使った項目は kakikudashi_unverified として返る" do
      expect(described_class.call("我読漢文")[:kakikudashi_unverified]).to match_array(%w[VERBS:読 DEFAULT:particle:読 FUNC:主題は])
    end
  end

  describe "ダミーの確認済み一覧を注入" do
    it "辞書項目を確認済みにしても、直書きの機能語（FUNC:不）が未確認なら exact:false（第2段 S8）" do
      stub_verified("VERBS" => %w[学])
      r = described_class.call("不学") # 使う項目は VERBS:学 と FUNC:不
      expect(r[:kakikudashi_tree_ok]).to be true
      expect(r[:kakikudashi_exact]).to be false
      expect(r[:kakikudashi_unverified]).to eq ["FUNC:不"]
    end

    it "動詞を確認済みにしても、既定の助詞を使えば exact:false（既定値だけが理由に残る）" do
      stub_verified("VERBS" => %w[読])
      r = described_class.call("我読漢文")
      expect(r[:kakikudashi_verified]).to be false
      expect(r[:kakikudashi_exact]).to be false
      expect(r[:kakikudashi_reasons]).to include(a_string_matching(/\A既定値: 助詞（読）/))
      expect(r[:kakikudashi_reasons].grep(/未確認の辞書項目: VERBS/)).to be_empty
    end

    it "助詞を明示した動詞（入）なら、確認済みで exact:true になる" do
      stub_verified("VERBS" => %w[入])
      r = described_class.call("返景入深林")
      expect(r[:kakikudashi_unverified]).to eq [] # 辞書項目（入）に未確認はない。FUNC・RULE は第2段 S10 以降
      expect(r[:kakikudashi_verified]).to be true
    end
  end

  describe "tree_ok と verified は独立" do
    let(:broken) { Kanbun::Yomi::Result.new("我は読む", [], nil, []) } # 漢文 が欠落。使った項目はなし（＝全部確認済み）

    it "検査に違反があれば、確認済みでも exact:false・暫定出力（tree_ok:false, verified:true）" do
      broken.parts = Kanbun::Yomi.analyze(KanbunParser.new.parse_tree("我読漢文", strict: true)).parts
      allow(Kanbun::Yomi).to receive(:analyze).and_return(broken)
      r = described_class.call("我読漢文")
      expect(r[:kakikudashi_tree_ok]).to be false
      expect(r[:kakikudashi_verified]).to be true
      expect(r[:kakikudashi_exact]).to be false
      expect(r[:kakikudashi]).to eq "我漢文読"
      expect(r[:kakikudashi_reasons]).to include("字の欠落: 漢")
    end

    it "読みの辞書にない語（MissingEntry）は tree_ok:false・verified:false" do
      r = described_class.call("寧為無為")
      expect(r[:kakikudashi_tree_ok]).to be false
      expect(r[:kakikudashi_verified]).to be false
      expect(r[:kakikudashi_exact]).to be false
    end
  end

  it "解析できない白文でも新しい項目を持つ（false・空）" do
    r = described_class.call("Ｘ")
    expect(r[:status]).to eq :unparsed
    expect(r).to include(kakikudashi_tree_ok: false, kakikudashi_verified: false, kakikudashi_unverified: [])
  end
end
