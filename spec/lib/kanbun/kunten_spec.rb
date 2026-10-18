require "rails_helper"
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/kunten").to_s
require Rails.root.join("lib/kanbun/kakikudashi").to_s

# 構文木 → 返り点。検算（Reorder で読み順に戻す）は Kunten.annotate が毎回行う。
RSpec.describe Kanbun::Kunten do
  let(:parser) { KanbunParser.new }

  def units_for(hakubun)
    Kanbun::Kunten.annotate(parser.parse_tree(hakubun, strict: true))
  end

  # [白文, 返り点つき, 読む順]
  def self.kunten_cases(title, rows)
    describe title do
      rows.each do |hakubun, bracket, reading|
        it "#{hakubun} => #{bracket}（#{reading}）" do
          units = units_for(hakubun)
          expect(Kanbun::Kunten.to_bracket(units)).to eq bracket
          expect(Kanbun::Kunten.reading(units)).to eq reading
        end
      end
    end
  end

  kunten_cases "否定・禁止（レ点）", [
    %w[不学 不[レ]学 学不], %w[莫笑 莫[レ]笑 笑莫],
    %w[不読書 不[レ]読[レ]書 書読不], %w[勿施人 勿[レ]施[レ]人 人施勿]
  ]

  kunten_cases "基本 5 文型（HB p.150）", [
    %w[花開鳥啼 花開鳥啼 花開鳥啼], %w[山紫水明 山紫水明 山紫水明], %w[孔子聖人 孔子聖人 孔子聖人],
    %w[我読漢文 我読[二]漢文[一] 我漢文読], %w[君子学道 君子学[レ]道 君子道学],
    %w[返景入深林 返景入[二]深林[一] 返景深林入],
    %w[苛政猛於虎 苛政猛[二]於虎[一] 苛政虎猛],
    %w[霜葉紅於二月花 霜葉紅[二]於二月花[一] 霜葉二月花紅],
    %w[君子揚名後世 君子揚[二]名後世[一] 君子名後世揚],
    %w[子問礼於老子 子問[二]礼於老子[一] 子礼老子問],
    %w[項梁教籍兵法 項梁教[二]籍兵法[一] 項梁籍兵法教],
    %w[陽貨帰孔子豚 陽貨帰[二]孔子豚[一] 陽貨孔子豚帰]
  ]

  kunten_cases "HB p.147–148 の返り点例（文法の範囲内のもの）", [
    %w[有備 有[レ]備 備有], %w[無患 無[レ]患 患無],
    %w[歳月不待人 歳月不[レ]待[レ]人 歳月人待不], %w[省吾身 省[二]吾身[一] 吾身省]
  ]

  kunten_cases "二重否定・部分否定", [
    %w[無非王土 無[レ]非[二]王土[一] 王土非無], %w[無不陥 無[レ]不[レ]陥 陥不無],
    %w[非不慎 非[レ]不[レ]慎 慎不非],
    %w[不必賢 不[二]必賢[一] 必賢不], %w[不常有 不[二]常有[一] 常有不],
    %w[不復得 不[二]復得[一] 復得不]
  ]

  kunten_cases "一二三点（同じ字で読み終わる返りの入れ子）", [
    %w[無不読漢文 無[レ]不[レ]読[二]漢文[一] 漢文読不無],
    %w[不必読漢文 不[三]必読[二]漢文[一] 必漢文読不],
    %w[不必読書 不[二]必読[レ]書[一] 必書読不],
    %w[我不読漢文 我不[レ]読[二]漢文[一] 我漢文読不]
  ]

  kunten_cases "比較・選択・抑揚", [
    %w[計莫如植 計莫[レ]如[レ]植 計植如莫], %w[地不若人 地不[レ]若[レ]人 地人若不],
    %w[与易寧戚 与[レ]易寧戚 易与寧戚],
    %w[寧為無為 寧為無[レ]為 寧為為無],
    %w[寧為鶏口無為牛後 寧為[二]鶏口[一]無[レ]為[二]牛後[一] 寧鶏口為牛後為無],
    %w[馬況人乎 馬況人乎 馬況人乎]
  ]

  kunten_cases "仮定・逆接・限定", [
    %w[若不成 若不[レ]成 若成不], %w[苟無成 苟無[レ]成 苟成無],
    %w[学雖無成 学雖[レ]無[レ]成 学成無雖], %w[独臣有船 独臣有[レ]船 独臣船有]
  ]

  kunten_cases "疑問・反語", [
    %w[不亦説乎 不[二]亦説[一]乎 亦説不乎], %w[豈学道哉 豈学[レ]道哉 豈道学哉],
    %w[学乎 学乎 学乎], %w[何為入深林 何為入[二]深林[一] 何為深林入]
  ]

  # 再読文字は 1 度目をその位置で、2 度目を返って読む（読む順に同じ字が 2 回出る）
  kunten_cases "再読文字（HB p.164）", [
    %w[未知 未[レ]知 未知未], %w[将行 将[レ]行 将行将],
    %w[応知故郷事 応[レ]知[二]故郷事[一] 応故郷事知応],
    %w[須読書 須[レ]読[レ]書 須書読須], %w[当学道 当[レ]学[レ]道 当道学当],
    %w[宜学 宜[レ]学 宜学宜], %w[盍学 盍[レ]学 盍学盍], %w[猶有 猶[レ]有 猶有猶],
    %w[過猶不及 過猶[レ]不[レ]及 過猶及不猶], %w[行楽須及春 行楽須[レ]及[レ]春 行楽須春及須],
    %w[我未知 我未[レ]知 我未知未], %w[未不知 未[レ]不[レ]知 未知不未]
  ]

  describe "再読文字の注記つき漢文（正本）" do
    it "1 度目の読み〈表示〉と 2 度目の読み〈非表示〉を書き出し、読み戻せる" do
      units = units_for("未知")
      text = Kanbun::Kunten.to_aozora(units)
      expect(text).to eq "未《いま》ダ〈ず〉［＃レ］知"
      expect(Kanbun::Aozora.parse(text)).to eq units
    end

    it "書き下しは 1 度目の読みと 2 度目の読みの両方を出す（活用の送り仮名は Phase 5）" do
      text = Kanbun::Kunten.to_aozora(units_for("応知故郷事"))
      expect(Kanbun::Kakikudashi.convert(text, yomi: false, hiragana: true)).to eq "応に故郷事知べし"
    end
  end

  kunten_cases "通し確認で出た白文", [
    %w[私食林檎 私食[二]林檎[一] 私林檎食], %w[私不読漢文 私不[レ]読[二]漢文[一] 私漢文読不],
    %w[彼不読書 彼不[レ]読[レ]書 彼書読不], %w[山高水清 山高水清 山高水清]
  ]

  kunten_cases "動詞が主語・副詞・連動", [
    %w[学楽 学楽 学楽], %w[月出夜明 月出夜明 月出夜明], %w[人皆死 人皆死 人皆死],
    %w[人皆食林檎 人皆食[二]林檎[一] 人皆林檎食], %w[亦学道 亦学[レ]道 亦道学],
    %w[飲茶読書 飲[レ]茶読[レ]書 茶飲書読], %w[私飲茶読書 私飲[レ]茶読[レ]書 私茶飲書読],
    %w[彼非君子 彼非[二]君子[一] 彼君子非]
  ]

  kunten_cases "辞書拡充・自作文（Phase 4i）", [
    %w[犬走 犬走 犬走],
    %w[先生教学生 先生教[二]学生[一] 先生学生教],
    %w[時間不待人 時間不[レ]待[レ]人 時間人待不],
    %w[氷冷於水 氷冷[二]於水[一] 氷水冷],
    %w[国興国滅 国興国滅 国興国滅],
    %w[老人帰山 老人帰[レ]山 老人山帰],
    %w[貧雖楽 貧雖[レ]楽 貧楽雖],
    %w[勿待人 勿[レ]待[レ]人 人待勿],
    %w[何為帰国 何為帰[レ]国 何為国帰],
    %w[山高於雲 山高[二]於雲[一] 山雲高],
    %w[小雖美 小雖[レ]美 小美雖],
    %w[若不来 若不[レ]来 若来不],
    %w[不亦喜乎 不[二]亦喜[一]乎 亦喜不乎],
    %w[誰行乎 誰行乎 誰行乎],
    %w[若不飲則死 若不[レ]飲則死 若飲不則死],
    %w[若学則愚 若学則愚 若学則愚]
  ]

  kunten_cases "使役・共同・而・則・矣（Phase 4m）", [
    %w[王使臣行 王使[二]臣行[一] 王臣行使],
    %w[王令臣行 王令[二]臣行[一] 王臣行令],
    %w[王使臣読書 王使[二]臣読[レ]書[一] 王臣書読使],
    %w[与友飲酒 与[レ]友飲[レ]酒 友与酒飲],
    %w[与友飲酒而語 与[レ]友飲[レ]酒而語 友与酒飲語],
    %w[母炊米而食 母炊[レ]米而食 母米炊食],
    %w[不学則不知道 不[レ]学則不[レ]知[レ]道 学不則道知不],
    %w[不知非恥 不[レ]知非[レ]恥 知不恥非],
    %w[昔人敬天矣 昔人敬[レ]天矣 昔人天敬],
    %w[雪白於炭 雪白[二]於炭[一] 雪炭白],
    %w[母炊米 母炊[レ]米 母米炊],
    %w[風吹雲流 風吹雲流 風吹雲流]
  ]

  # 唐詩の句（王維・李白・杜甫・白居易。いずれも著作権切れ）。辞書・文法の拡充（Phase 4h）の確認。
  # 返り点は市販の学習書の表記と一致することを確かめてあるが、書き下しや解説は転載しない。
  kunten_cases "漢詩の句（Phase 4h）", [
    %w[空山不見人 空山不[レ]見[レ]人 空山人見不],
    %w[但聞人語響 但聞[二]人語響[一] 但人語響聞],
    %w[復照青苔上 復照[二]青苔上[一] 復青苔上照],
    %w[春夜洛城聞笛 春夜洛城聞[レ]笛 春夜洛城笛聞],
    %w[誰家玉笛暗飛声 誰家玉笛暗飛[レ]声 誰家玉笛暗声飛],
    %w[散入春風満洛城 散入[二]春風[一]満[二]洛城[一] 散春風入洛城満],
    %w[此夜曲中聞折柳 此夜曲中聞[二]折柳[一] 此夜曲中折柳聞],
    %w[何人不起故園情 何人不[レ]起[二]故園情[一] 何人故園情起不],
    %w[好雨知時節 好雨知[二]時節[一] 好雨時節知],
    %w[随風潜入夜 随[レ]風潜入[レ]夜 風随潜夜入],
    %w[潤物細無声 潤[レ]物細無[レ]声 物潤細声無],
    %w[野径雲倶黒 野径雲倶黒 野径雲倶黒],
    %w[江船火独明 江船火独明 江船火独明],
    %w[花重錦官城 花重[二]錦官城[一] 花錦官城重],
    %w[小閣重衾不怕寒 小閣重[レ]衾不[レ]怕[レ]寒 小閣衾重寒怕不],
    %w[遺愛寺鐘欹枕聴 遺愛寺鐘欹[レ]枕聴 遺愛寺鐘枕欹聴],
    %w[香炉峰雪撥簾看 香炉峰雪撥[レ]簾看 香炉峰雪簾撥看],
    %w[故郷何独在長安 故郷何独在[二]長安[一] 故郷何独長安在]
  ]

  describe "上下点・甲乙点（手で組んだ木で段の切り替えを確かめる）" do
    def leaf(s, silent: false) = Kanbun::Tree::Leaf.new(s, silent: silent)
    def ret(head, *block) = Kanbun::Tree::Ret.new(leaf(head), block)

    it "HB: 不[下]為[二]児孫[一]買[中]美田[上]" do
      tree = ret("不", ret("為", leaf("児孫")), ret("買", leaf("美田")))
      units = Kanbun::Kunten.annotate(tree)
      expect(Kanbun::Kunten.to_bracket(units)).to eq "不[下]為[二]児孫[一]買[中]美田[上]"
      expect(Kanbun::Kunten.reading(units)).to eq "児孫為美田買不"
    end

    it "さらに外側を包むと甲乙点になる" do
      inner = ret("不", ret("為", leaf("児孫")), ret("買", leaf("美田")))
      tree = ret("何", inner, ret("従", leaf("之")))
      units = Kanbun::Kunten.annotate(tree)
      expect(Kanbun::Kunten.to_bracket(units)).to eq "何[乙]不[下]為[二]児孫[一]買[中]美田[上]従[レ]之[甲]"
    end
  end

  describe "出力形式" do
    it "注記つき漢文（正本）に書き出せ、読み戻した単位列が一致する" do
      units = units_for("子問礼於老子")
      text = Kanbun::Kunten.to_aozora(units)
      expect(text).to eq "子問［＃二］礼於〈〉老子［＃一］"
      expect(Kanbun::Aozora.parse(text)).to eq units
    end

    it "複数字の述語が返るときは竪点（U+2010）でつなぐ（見聞は 1 語として返る）" do
      units = units_for("見聞道")
      expect(Kanbun::Kunten.to_aozora(units)).to eq "見‐聞［＃レ］道"
      expect(Kanbun::Kunten.reading(units)).to eq "道見聞"
    end

    it "複数字の語へ返るときは一二点（レ点は 1 字だけ）" do
      expect(Kanbun::Kunten.to_bracket(units_for("不見聞"))).to eq "不[二]見聞[一]"
    end

    it "書き出しで単位列を壊さない（to_aozora を 2 回呼んでも同じ）" do
      units = units_for("我読漢文")
      expect(Kanbun::Kunten.to_aozora(units)).to eq Kanbun::Kunten.to_aozora(units)
      expect(Kanbun::Kunten.to_bracket(units)).to eq "我読[二]漢文[一]"
    end

    it "置字は読み順に含めない" do
      expect(Kanbun::Kunten.reading(units_for("苛政猛於虎"))).to eq "苛政虎猛"
    end
  end

  describe "辞書にない字" do
    it "strict では拒否する（返り点がずれるため）" do
      expect { parser.parse_tree("不読Ｘ", strict: true) }.to raise_error(KanbunParser::UnknownCharacters)
    end

    it "既定では従来どおり読み飛ばす" do
      expect(parser.parse("不読Ｘ")).to eq "不読"
    end
  end
end
