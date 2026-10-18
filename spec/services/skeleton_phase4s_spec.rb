# frozen_string_literal: true

require "rails_helper"

# Phase 4s: 仮定の否定「〜なければ〜ない」→ 不〜則不〜。
# MeCab の出力は IPA 辞書の分類（未然形＋助動詞 ない の仮定形 なけれ＋接続助詞 ば）を再現したもの。
RSpec.describe "仮定の骨格（Phase 4s）" do
  def skeleton_for(mecab_output)
    tokens = MeCabAdapter.call(mecab_output)
    result = KanbunBNFParser.new(tokens).parse
    result && SkeletonBuilder.call(result)
  end

  it "学ばなければ道を知らない → 不 学ぶ 則 不 知る 道" do
    mecab = <<~MECAB
      学ば\t動詞,自立,*,*,五段・バ行,未然形,学ぶ,マナバ,マナバ
      なけれ\t助動詞,*,*,*,特殊・ナイ,仮定形,ない,ナケレ,ナケレ
      ば\t助詞,接続助詞,*,*,*,*,ば,バ,バ
      道\t名詞,一般,*,*,*,*,道,ミチ,ミチ
      を\t助詞,格助詞,一般,*,*,*,を,ヲ,ヲ
      知ら\t動詞,自立,*,*,五段・ラ行,未然形,知る,シラ,シラ
      ない\t助動詞,*,*,*,特殊・ナイ,基本形,ない,ナイ,ナイ
      EOS
    MECAB
    expect(skeleton_for(mecab)).to eq "不 学ぶ 則 不 知る 道"
  end

  it "飲まなければ死ぬ → 不 飲む 則 死ぬ" do
    mecab = <<~MECAB
      飲ま\t動詞,自立,*,*,五段・マ行,未然形,飲む,ノマ,ノマ
      なけれ\t助動詞,*,*,*,特殊・ナイ,仮定形,ない,ナケレ,ナケレ
      ば\t助詞,接続助詞,*,*,*,*,ば,バ,バ
      死ぬ\t動詞,自立,*,*,五段・ナ行,基本形,死ぬ,シヌ,シヌ
      EOS
    MECAB
    expect(skeleton_for(mecab)).to eq "不 飲む 則 死ぬ"
  end

  it "ば のない文は従来どおり" do
    mecab = <<~MECAB
      犬\t名詞,一般,*,*,*,*,犬,イヌ,イヌ
      が\t助詞,格助詞,一般,*,*,*,が,ガ,ガ
      走る\t動詞,自立,*,*,五段・ラ行,基本形,走る,ハシル,ハシル
      EOS
    MECAB
    expect(skeleton_for(mecab)).to eq "犬 走る"
  end
end
