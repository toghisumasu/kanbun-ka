require "rails_helper"
require Rails.root.join("lib/kanbun/verified_entries").to_s

# Phase 6a S3: 確認済み印の一覧。本番の一覧（verified_entries.yml）ではなく、ダミー一覧を注入して試す。
RSpec.describe Kanbun::VerifiedEntries do
  let(:dummy) { described_class.new("VERBS" => %w[学], "ADVS" => %w[皆]) }

  it "一覧にある項目は確認済み、ない項目は未確認" do
    expect(dummy.verified?("VERBS:学")).to be true
    expect(dummy.verified?("ADVS:皆")).to be true
    expect(dummy.verified?("VERBS:読")).to be false
    expect(dummy.verified?("ADJS:賢")).to be false
  end

  it "同じキーでも表が違えば別の項目" do
    expect(dummy.verified?("ADVS:学")).to be false
  end

  it "DEFAULT 項目は確認済みにならない" do
    expect(dummy.verified?("DEFAULT:particle:学")).to be false
    expect(dummy.verified?("DEFAULT:form:学")).to be false
  end

  it "DEFAULT という表を一覧に書いたら拒否する" do
    expect { described_class.new("DEFAULT" => %w[particle:学]) }.to raise_error(described_class::Invalid, /DEFAULT/)
  end

  it "未確認の項目だけを、順序を保って返す（DEFAULT も未確認）" do
    ids = %w[VERBS:学 VERBS:読 DEFAULT:particle:読 ADVS:皆 ADJS:賢]
    expect(dummy.unverified(ids)).to eq %w[VERBS:読 DEFAULT:particle:読 ADJS:賢]
  end

  it "使った項目が空なら、すべて確認済み（未確認なし）" do
    expect(dummy.unverified([])).to eq []
  end

  it "知らない表名・辞書にないキーは拒否する（打ち間違いで確認済みにならない）" do
    expect { described_class.new("VERB" => %w[学]) }.to raise_error(described_class::Invalid, /表/)
    expect { described_class.new("VERBS" => %w[虹]) }.to raise_error(described_class::Invalid, /虹/)
  end

  describe "ファイルの読み込み" do
    it "本番の verified_entries.yml は空から始まる（確認済み 0 件）" do
      list = described_class.load
      expect(list.count).to eq 0
      expect(list.verified?("VERBS:学")).to be false
    end

    it "YAML ファイルから読める" do
      require "tempfile"
      Tempfile.create(["v", ".yml"]) do |f|
        f.write("VERBS:\n  - 学\nADVS:\n  - 皆\n")
        f.flush
        list = described_class.load(f.path)
        expect(list.count).to eq 2
        expect(list.verified?("VERBS:学")).to be true
      end
    end

    it "表のキー配列でないときは拒否する" do
      require "tempfile"
      Tempfile.create(["v", ".yml"]) do |f|
        f.write("VERBS: 学\n")
        f.flush
        expect { described_class.load(f.path) }.to raise_error(described_class::Invalid)
      end
    end
  end
end
