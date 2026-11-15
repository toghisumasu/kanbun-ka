require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
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

  describe "FUNC（直書きの機能語）と RULE（文法規則）の節（第2段 S10）" do
    let(:list) { described_class.new("FUNC" => %w[不 乎@silent], "RULE" => ["neg_clause/NEG_BU verb_phrase"]) }

    it "FUNC・RULE の項目も確認済みにできる" do
      expect(list.verified?("FUNC:不")).to be true
      expect(list.verified?("FUNC:乎@silent")).to be true
      expect(list.verified?("RULE:neg_clause/NEG_BU verb_phrase")).to be true
    end

    it "一覧にない FUNC・RULE は未確認" do
      expect(list.verified?("FUNC:乎")).to be false
      expect(list.verified?("RULE:verb_phrase/NOUN NOUN")).to be false
    end

    it "知らない機能語・規則名は拒否する" do
      expect { described_class.new("FUNC" => %w[虹]) }.to raise_error(described_class::Invalid, /虹/)
      expect { described_class.new("RULE" => ["verb_phrase/NOUN NOUN NOUN"]) }.to raise_error(described_class::Invalid, /NOUN NOUN NOUN/)
    end

    it "Yomi が記録しうる FUNC の ID は、すべて一覧に書ける（書けない ID を出さない）" do
      ids = %w[不学 彼非君子也 学而不行 入於深林焉 若学則楽 不得不知 不可不行 王使臣行 彼為敵所殺 見殺 人莫若友 非徒無益而又害之
               我読漢文 未知故郷事 入乎深林 学乎 其疾如風 与友飲酒 彼自鹿児島来 勿待人 無所知 学哉 学邪 彼被殺].flat_map do |h|
        tree = KanbunParser.new.parse_tree(h, strict: true)
        Kanbun::Yomi.analyze(tree).used_entries.grep(/\A(FUNC|RULE):/)
      end.uniq
      expect(ids).not_to be_empty
      expect { described_class.new(ids.group_by { |i| i[/\A\w+/] }.transform_values { |v| v.map { |i| i.sub(/\A\w+:/, "") } }) }.not_to raise_error
    end
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
