require "rails_helper"

# LLM の出力を白文の形に整える normalize（繁体字を日本の字体へ、1 行目だけ、空白を除く）。
RSpec.describe KanbunTranslatorService do
  def normalize(raw)
    KanbunTranslatorService.new("x").send(:normalize, raw)
  end

  it "繁体字を日本の字体に直す" do
    expect(normalize("先生教學生")).to eq "先生教学生"
    expect(normalize("國興國滅")).to eq "国興国滅"
  end

  it "簡体字・繁体字（樂・歸・冰・处）も直す" do
    expect(normalize("不亦樂乎")).to eq "不亦楽乎"
    expect(normalize("老人歸山")).to eq "老人帰山"
    expect(normalize("冰莫如水冷")).to eq "氷莫如水冷"
    expect(normalize("勿笑此处")).to eq "勿笑此処"
  end

  it "空白を除き、最初の 1 行だけ取る" do
    expect(normalize("彼 不 読書\n説明文")).to eq "彼不読書"
  end

  it "文字列でなければそのまま返す" do
    expect(normalize(nil)).to be_nil
  end

  describe "drop_stray_question_marker（Phase 4t）" do
    def drop(input, hakubun, skeleton)
      KanbunTranslatorService.new(input).send(:drop_stray_question_marker, hakubun, skeleton)
    end

    it "疑問でない文に混じった乎を除く" do
      expect(drop("学ばなければ道を知らない", "不学則不知乎道", "不 学ぶ 則 不 知る 道")).to eq "不学則不知道"
    end

    it "骨格に乎があれば残す" do
      expect(drop("君は学ぶか", "君学乎", "君 学ぶ 乎")).to eq "君学乎"
    end

    it "原文に か があれば残す" do
      expect(drop("楽しくないか", "不亦楽乎", "不 楽しい")).to eq "不亦楽乎"
    end

    it "骨格がなければそのまま" do
      expect(drop("山は雲より高い", "山高於乎雲", nil)).to eq "山高於乎雲"
    end
  end

  describe "restore_compound_words（Phase 4x）" do
    def restore(hakubun, skeleton)
      KanbunTranslatorService.new("").send(:restore_compound_words, hakubun, skeleton)
    end

    it "縮められた漢語を元に戻す（望見 → 望）" do
      expect(restore("私自鹿児島能望閃光", "私 自 鹿児島 能 望見 閃光")).to eq "私自鹿児島能望見閃光"
    end

    it "語がそのまま残っていれば何もしない" do
      expect(restore("私自鹿児島能望見閃光", "私 自 鹿児島 能 望見 閃光")).to eq "私自鹿児島能望見閃光"
    end

    it "辞書にある字への言い換えは戻さない（子供 → 子）" do
      expect(restore("子飲水", "子供 飲む 水")).to eq "子飲水"
    end

    it "骨格がなければ何もしない" do
      expect(restore("私能望閃光", nil)).to eq "私能望閃光"
    end
  end

  describe "restore_leading_subject（Phase 4x）" do
    def restore(hakubun, skeleton)
      KanbunTranslatorService.new("").send(:restore_leading_subject, hakubun, skeleton)
    end

    it "マーカーで始まる白文に、落とされた主語を戻す" do
      expect(restore("自鹿児島能望見閃光", "私 自 鹿児島 能 望見 閃光")).to eq "私自鹿児島能望見閃光"
    end

    it "主語が残っていれば何もしない" do
      expect(restore("私自鹿児島能望見閃光", "私 自 鹿児島 能 望見 閃光")).to eq "私自鹿児島能望見閃光"
    end

    it "主語を別の語に言い換えていれば触らない（私 → 我）" do
      expect(restore("我自鹿児島来", "私 自 鹿児島 来る")).to eq "我自鹿児島来"
    end

    it "骨格がマーカーで始まる文は触らない" do
      expect(restore("不学則不知道", "不 学ぶ 則 不 知る 道")).to eq "不学則不知道"
      expect(restore("有足於蛇", "有 足 於 蛇")).to eq "有足於蛇"
    end

    it "白文が語で始まっていれば触らない（主語の言い換え・省略は許す）" do
      expect(restore("食林檎", "私 食べる 林檎")).to eq "食林檎"
    end
  end
end
