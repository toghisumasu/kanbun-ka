# 生成: bundle exec racc -v script/kanbun_parser.y -o lib/kanbun/kanbun_parser.tab.rb
class KanbunParser

# トークン定義（フェーズ1 + 部分否定用トークンを追加）
token NEG_BU NEG_FU NEG_HI NEG_MU NEG_BAKU
      PROHIBIT_NAKA
      HITSZU JOU MATA        # 必・常・復（部分否定用）
      MOKU_NAKU MOKU_SHIKA
      FUSHIKA FUNYUU
      YO_NIMO  NAMU IWA_N_YA
      KATEN_SHIKA KATEN_NYO KATEN_IYA
      KATEN_IEDOMO KATEN_TATOI
      GENTEI_YUI GENTEI_DOKU
      SHI_KO SHI_SAI SHI_JA
      HAN_AI FUKI_MATA
      GI_AN GI_DARE GI_IZURE GI_NANI
      GI_NANSURU GI_NANMOTE GI_IKANI_A GI_IKANI_B
      SOKU SHI_I SHIEKI ER SHO SHA
      VERB VERB_I NOUN ADJ ADV PREP SAIDOKU

rule
  sentence
    : clause         { result = val[0] }
    | clause SHI_I   { result = seq(val[0], lf('矣', true)) }   # 文末の置き字「矣」（Phase 4m）

  clause
    : double_neg_clause  { result = val[0] }   # 二重否定
    | partial_neg_clause { result = val[0] }   # 部分否定
    | compare_clause     { result = val[0] }
    | select_clause      { result = val[0] }
    | suppress_clause    { result = val[0] }
    | katen_clause       { result = val[0] }
    | gyaku_katen_clause { result = val[0] }
    | gentei_clause      { result = val[0] }
    | hangi_clause       { result = val[0] }
    | shitsumon_clause   { result = val[0] }
    | gi_adv_clause      { result = val[0] }
    | neg_clause         { result = val[0] }   # 否定（フェーズ1）
    | prohibit_clause    { result = val[0] }   # 禁止（フェーズ1）
    | saidoku_clause     { result = val[0] }   # 再読文字（Phase 4d）
    | ren_clause         { result = val[0] }   # 〜而〜（Phase 4m）
    | sokuclause         { result = val[0] }   # 〜則〜（Phase 4m）
    | seq_neg_clause     { result = val[0] }   # 否定の連続 不知非恥（Phase 4m）
    | shieki_clause      { result = val[0] }   # 使役（Phase 4m）
    | tomo_clause        { result = val[0] }   # 与A〜（Phase 4m）
    | subj_neg_clause    { result = val[0] }   # 主語＋否定・禁止（Phase 4c）
    | mata_clause        { result = val[0] }   # 文頭の副詞「復」（Phase 4h）
    | verb_phrase        { result = val[0] }

  # 各規則は構文木（Kanbun::Tree）を返す。読む順は 2 つの部品で表す。
  #   seq(a, b, …)        左から右へそのまま読む
  #   ret(head, a, b, …)  a, b, … を読んでから head に返って読む（返り点が付く）

  # ---- 主語＋否定・禁止（Phase 4c）----
  # 歳月不待人 → 歳月 | 不待人。主語は名詞 1 トークン（複数字の主語は辞書で 1 語にする）。
  subj_neg_clause
    : NOUN neg_clause         { result = seq(lf(val[0]), val[1]) }
    | NOUN prohibit_clause    { result = seq(lf(val[0]), val[1]) }
    | NOUN double_neg_clause  { result = seq(lf(val[0]), val[1]) }
    | NOUN partial_neg_clause { result = seq(lf(val[0]), val[1]) }
    | NOUN saidoku_clause     { result = seq(lf(val[0]), val[1]) }
    | NOUN neg_clause SHI_KO  { result = seq(lf(val[0]), val[1], lf('乎')) }   # 此不楽乎（Phase 4o）
    | NOUN shieki_clause      { result = seq(lf(val[0]), val[1]) }   # 王使臣行（Phase 4m）
    | NOUN pred_obj neg_clause           { result = seq(lf(val[0]), val[1], val[2]) }  # 小閣重衾不怕寒（Phase 4h）
    | pred_obj ADV neg_clause            { result = seq(val[0], lf(val[1]), val[2]) }  # 潤物細無声

  # ---- 条件「AなればB」の則（Phase 4m）。若〜則〜 は katen_clause が先に受ける ----
  sokuclause
    : cond_part SOKU cond_part { result = seq(val[0], lf('則'), val[2]) }

  cond_part
    : verb_phrase { result = val[0] }
    | neg_clause  { result = val[0] }

  # ---- 順接の「而」。読まない置き字（Vシテ）として位置だけ占める（Phase 4m）----
  ren_clause
    : ren_part ER ren_part { result = seq(val[0], lf('而', true), val[2]) }

  ren_part
    : verb_phrase { result = val[0] }
    | tomo_clause { result = val[0] }

  # ---- 否定の連続 不知非恥（知らざるは恥に非ず）----
  seq_neg_clause
    : neg_clause neg_clause { result = seq(val[0], val[1]) }

  # ---- 使役 使A〜（AをしてVせしむ）。使は A と V のあとに返って読む ----
  shieki_clause
    : SHIEKI NOUN verb_phrase { result = ret(lf(val[0]), lf(val[1]), val[2]) }

  # ---- 共同 与A〜（Aと〜）。与 は A のあとに読む ----
  tomo_clause
    : YO_NIMO NOUN verb_phrase { result = seq(ret(lf('与'), lf(val[1])), val[2]) }

  # ---- 文頭の「復」（また）。部分否定 不復〜 は NEG_BU MATA で別に受ける（Phase 4h）----
  mata_clause
    : MATA verb_phrase { result = seq(lf(val[0]), val[1]) }

  # ---- 二重否定句法 ----
  # 無非〜：〜でないものはない（全て〜である）
  # 無不〜：〜しないものはない（全て〜する）
  # 非不〜：〜しないのではない（〜しないわけではない）
  double_neg_clause
    : NEG_MU NEG_HI verb_phrase { result = ret(lf('無'), ret(lf('非'), val[2])) }
    | NEG_MU NEG_BU verb_phrase { result = ret(lf('無'), ret(lf('不'), val[2])) }
    | NEG_HI NEG_BU verb_phrase { result = ret(lf('非'), ret(lf('不'), val[2])) }
    | NEG_MU NEG_BU verb_phrase SHA { result = ret(lf('無'), ret(lf('不'), val[2]), lf('者')) }   # 無不飲者（Phase 4o）
    | NEG_MU SHO    verb_phrase     { result = ret(lf('無'), ret(lf('所'), val[2])) }              # 無所知（Phase 4o）

  # ---- 部分否定句法 ----
  # 不必〜：必ずしも〜ではない  不常〜：いつも〜とは限らない  不復〜：二度と〜しない
  partial_neg_clause
    : NEG_BU HITSZU verb_phrase { result = ret(lf('不'), lf('必'), val[2]) }
    | NEG_BU JOU    verb_phrase { result = ret(lf('不'), lf('常'), val[2]) }
    | NEG_BU MATA   verb_phrase { result = ret(lf('不'), lf('復'), val[2]) }

  # ---- 否定句法 ----
  neg_clause
    : NEG_BU   verb_phrase { result = ret(lf(val[0]), val[1]) }
    | NEG_FU   verb_phrase { result = ret(lf(val[0]), val[1]) }
    | NEG_HI   verb_phrase { result = ret(lf(val[0]), val[1]) }
    | NEG_MU   verb_phrase { result = ret(lf(val[0]), val[1]) }
    | NEG_BAKU verb_phrase { result = ret(lf(val[0]), val[1]) }

  # ---- 禁止句法 ----
  prohibit_clause
    : PROHIBIT_NAKA verb_phrase { result = ret(lf(val[0]), val[1]) }

  # ---- 再読文字（Phase 4d。未・将・当・応・宜・須・猶・盍）----
  # 構文は否定と同形（head が block のあとに読まれる）。違いは 1 字を 2 度読むこと。
  #   未知 → いまだ(1度目) 知(る) ず(2度目)。1 度目は元の位置、2 度目は返り点に従う。
  # 猶不及（猶ホ及バザルガゴトシ）のように、否定を挟む形も受ける。
  saidoku_clause
    : SAIDOKU verb_phrase { result = ret(lf_saidoku(val[0]), val[1]) }
    | SAIDOKU neg_clause  { result = ret(lf_saidoku(val[0]), val[1]) }

  # ---- 動詞句 = 基本構文 5 文型（Phase 4b。HB p.150）----
  # 返り点は語順（構文）で決まり、ヲ／ニの別は辞書（動詞の格情報）で決まる。
  # そのため ②読漢文(ヲ)と③入深林(ニ)、④揚名後世と⑤教籍兵法 は同じ形の規則で受ける。
  verb_phrase
    : pred_tr                  { result = val[0] }   # 述語のみ（他動・多義の VERB）
    | pred_in                  { result = val[0] }   # 述語のみ（自動詞・形容詞）
    | NOUN                     { result = lf(val[0]) }                   # 名詞だけ
    | NOUN NOUN                { result = seq(lf(val[0]), lf(val[1])) }  # ① 孔子聖人（名詞述語）
    | NOUN pred_tr             { result = seq(lf(val[0]), val[1]) }      # ②〜⑤ 我読漢文・返景入深林…
    | NOUN ADV pred_tr         { result = seq(lf(val[0]), lf(val[1]), val[2]) }  # 人皆食林檎
    | ADV pred_tr              { result = seq(lf(val[0]), val[1]) }      # 亦学道
    | ADV pred_in              { result = seq(lf(val[0]), val[1]) }      # 皆死
    | pred_obj pred_tr         { result = seq(val[0], val[1]) }          # 連動 飲茶読書（茶を飲みて書を読む）
    | NOUN pred_obj pred_tr    { result = seq(lf(val[0]), val[1], val[2]) }  # 私飲茶読書
    | NOUN NOUN pred_tr        { result = seq(lf(val[0]), lf(val[1]), val[2]) }  # 春夜洛城聞笛（Phase 4h）
    | NOUN NOUN pred_obj pred_tr { result = seq(lf(val[0]), lf(val[1]), val[2], val[3]) }  # 遺愛寺鐘欹枕聴
    | NOUN NOUN ADV pred_tr    { result = seq(lf(val[0]), lf(val[1]), lf(val[2]), val[3]) }  # 誰家玉笛暗飛声
    | pred_obj ADV pred_tr     { result = seq(val[0], lf(val[1]), val[2]) }      # 随風潜入夜
    | ADV pred_obj pred_tr     { result = seq(lf(val[0]), val[1], val[2]) }      # 散入春風満洛城
    | NOUN sv                  { result = seq(lf(val[0]), val[1]) }              # 野径雲倶黒（主題＋主述）
    | sv sv NOUN NOUN          { result = seq(val[0], val[1], lf(val[2]), lf(val[3])) }  # 心泰身寧是帰処
    | sv                       { result = val[0] }   # ① 山紫・花開
    | sv sv                    { result = seq(val[0], val[1]) }          # ① 花開鳥啼・山紫水明（対句）

  # 主語＋自動詞／形容詞。自動詞（VERB_I）で切るので 花開|鳥啼 が 花 開鳥 と誤読されない。
  # 動詞が主語になる 学楽（学ぶことは楽しい）も受ける。副詞つきは 人皆死。
  sv
    : NOUN pred_in             { result = seq(lf(val[0]), val[1]) }
    | NOUN ADV pred_in         { result = seq(lf(val[0]), lf(val[1]), val[2]) }
    | VERB pred_in             { result = seq(lf(val[0]), val[1]) }
    | NOUN GENTEI_DOKU pred_in { result = seq(lf(val[0]), lf(val[1]), val[2]) }   # 江船火独明（Phase 4h）

  # 他動・多義の述語：目的語（②④⑤）・補語（③）・置字つき補語。述語は目的語・補語のあとに読む。
  pred_tr
    : VERB                     { result = lf(val[0]) }
    | VERB VERB                { result = ret(lf(val[0]), lf(val[1])) }                   # 前の動詞が返って読む（暫定）
    | VERB PREP NOUN           { result = ret(lf(val[0]), lf(val[1], true), lf(val[2])) } # ③ 置字つき補語
    | pred_obj                 { result = val[0] }

  # 目的語・補語を取る述語（連動の前半にもなる）
  pred_obj
    : VERB NOUN                { result = ret(lf(val[0]), lf(val[1])) }                   # ② 読漢文 / ③ 入深林
    | VERB NOUN NOUN           { result = ret(lf(val[0]), lf(val[1]), lf(val[2])) }       # ④ 揚名後世 / ⑤ 教籍兵法
    | VERB NOUN PREP NOUN      { result = ret(lf(val[0]), lf(val[1]), lf(val[2], true), lf(val[3])) } # ④ 問礼於老子

  # 自動詞・形容詞の述語：補語（比較ヨリ・場所ニ）は置字で受ける
  pred_in
    : VERB_I                   { result = lf(val[0]) }
    | ADJ                      { result = lf(val[0]) }
    | VERB_I PREP NOUN         { result = ret(lf(val[0]), lf(val[1], true), lf(val[2])) }
    | ADJ PREP NOUN            { result = ret(lf(val[0]), lf(val[1], true), lf(val[2])) } # ③ 猛於虎・紅於二月花

  # 比較句法（莫如・莫若・不若・不如）
  # 百年之計莫如植樹 → 百年の計は樹を植えるに如くは莫し（計 樹 植 如 莫 の順に読む）
  compare_clause
    : verb_phrase MOKU_NAKU  verb_phrase { result = seq(val[0], ret(lf('莫'), ret(lf('如'), val[2]))) }
    | verb_phrase MOKU_SHIKA verb_phrase { result = seq(val[0], ret(lf('莫'), ret(lf('若'), val[2]))) }
    | verb_phrase FUSHIKA    verb_phrase { result = seq(val[0], ret(lf('不'), ret(lf('若'), val[2]))) }
    | verb_phrase FUNYUU     verb_phrase { result = seq(val[0], ret(lf('不'), ret(lf('如'), val[2]))) }

  # 選択句法（与A寧B・寧A無B）
  # 喪与易寧戚 → AせんよりはむしろB
  select_clause
    : YO_NIMO verb_phrase NAMU   verb_phrase { result = seq(ret(lf('与'), val[1]), lf('寧'), val[3]) }
    | NAMU    verb_phrase NEG_MU verb_phrase { result = seq(lf('寧'), val[1], ret(lf('無'), val[3])) }

  # 抑揚句法（況〜乎）
  # 死馬且買之、況生者乎 → AすらかつB、いわんやCをや（返り点なし）
  suppress_clause
    : verb_phrase IWA_N_YA verb_phrase SHI_KO { result = seq(val[0], lf('況'), val[2], lf('乎')) }

  # 仮定法・前置型（若/如/苟 ＋ 動詞句）
  # 若不成 → もし成らずんば
  katen_clause
    : KATEN_SHIKA     verb_phrase         { result = seq(lf('若'), val[1]) }
    | KATEN_SHIKA     NEG_BU verb_phrase  { result = seq(lf('若'), ret(lf('不'), val[2])) }
    | KATEN_NYO       verb_phrase         { result = seq(lf('如'), val[1]) }
    | KATEN_NYO       NEG_BU verb_phrase  { result = seq(lf('如'), ret(lf('不'), val[2])) }
    | KATEN_IYA       verb_phrase         { result = seq(lf('苟'), val[1]) }
    | KATEN_SHIKA     verb_phrase SOKU verb_phrase        { result = seq(lf('若'), val[1], lf('則'), val[3]) }  # 若〜則〜（Phase 4l）
    | KATEN_SHIKA     NEG_BU verb_phrase SOKU verb_phrase { result = seq(lf('若'), ret(lf('不'), val[2]), lf('則'), val[4]) }
    | KATEN_IYA       NEG_MU verb_phrase  { result = seq(lf('苟'), ret(lf('無'), val[2])) }

  # 仮定法・逆接型（〜雖〜 / 〜縦〜）
  # 学雖無成 → たとひ学業成らずとも。雖は block を読んでから返る。
  # 縦は「たとひ」と先に読む副詞なので、返らずそのまま読む（暫定）。
  gyaku_katen_clause
    : verb_phrase KATEN_IEDOMO    verb_phrase { result = seq(val[0], ret(lf('雖'), val[2])) }
    | verb_phrase KATEN_IEDOMO NEG_MU verb_phrase { result = seq(val[0], ret(lf('雖'), ret(lf('無'), val[3]))) }
    | verb_phrase KATEN_TATOI     verb_phrase { result = seq(val[0], lf('縦'), val[2]) }

  # 限定句法（惟〜 / 独〜）
  # 惟士 → ただ士のみ
  gentei_clause
    : GENTEI_YUI      verb_phrase { result = seq(lf('惟'), val[1]) }
    | GENTEI_DOKU     verb_phrase { result = seq(lf('独'), val[1]) }

  # --- 疑問句法（文末助字） ---
  shitsumon_clause
    : verb_phrase SHI_KO          { result = seq(val[0], lf('乎')) }
    | verb_phrase SHI_JA          { result = seq(val[0], lf('邪')) }
    | neg_clause  SHI_KO          { result = seq(val[0], lf('乎')) }   # 此不楽乎の 不楽乎（Phase 4o）
    | verb_phrase YO_NIMO         { result = seq(val[0], lf('与')) }
    ;

  # --- 反語句法 ---
  # 不亦〜乎：亦た〜ずや（亦 vp 不 乎 の順に読む）
  hangi_clause
    : HAN_AI      verb_phrase SHI_SAI  { result = seq(lf('豈'), val[1], lf('哉')) }
    | FUKI_MATA   verb_phrase SHI_KO   { result = seq(ret(lf('不'), lf('亦'), val[1]), lf('乎')) }
    | NAMU        verb_phrase SHI_KO   { result = seq(lf('寧'), val[1], lf('乎')) }
    | GENTEI_DOKU verb_phrase SHI_KO   { result = seq(lf('独'), val[1], lf('乎')) }
    | GENTEI_DOKU verb_phrase SHI_SAI  { result = seq(lf('独'), val[1], lf('哉')) }
    ;

  # --- 疑問副詞句法 ---
  gi_adv_clause
    : GI_AN      VERB        { result = seq(lf('安'), lf(val[1])) }
    | GI_DARE    verb_phrase { result = seq(lf('誰'), val[1]) }
    | GI_DARE    verb_phrase SHI_KO { result = seq(lf('誰'), val[1], lf('乎')) }   # 誰行乎（Phase 4l）
    | GI_IZURE   NOUN VERB   { result = seq(lf('孰'), lf(val[1]), lf(val[2])) }
    | GI_NANSURU verb_phrase { result = seq(lf('何為'), val[1]) }
    | GI_NANMOTE verb_phrase { result = seq(lf('何以'), val[1]) }
    | GI_IKANI_A verb_phrase { result = seq(lf('何如'), val[1]) }
    | GI_IKANI_B verb_phrase { result = seq(lf('如何'), val[1]) }
    | GI_NANI    verb_phrase { result = seq(lf('何'), val[1]) }
    ;
  end

---- header
require 'strscan'
require_relative 'lexicon'
require_relative 'tree'

---- inner

# 辞書は lib/kanbun/lexicon.rb に集約（Phase 4a）。旧定数は互換のため残す。
VERBS = Kanbun::Lexicon::VERBS
NOUNS = Kanbun::Lexicon::NOUNS

# 辞書にない文字（読み飛ばした文字）。Phase 4 以降の診断用。
attr_reader :skipped

# 辞書にない字があったことを知らせる（strict: true のとき）。
# 返り点は字数・位置で決まるため、字を黙って捨てると誤った返り点になる。
class UnknownCharacters < StandardError; end

# 白文を解析して構文木（Kanbun::Tree）を返す。返り点は Kanbun::Kunten.annotate で付ける。
# strict: true なら、辞書にない字を含む入力は UnknownCharacters で拒否する。
def parse_tree(str, strict: false)
  @tokens = tokenize(str)
  if strict && !@skipped.empty?
    raise UnknownCharacters, "辞書にない字があります: #{@skipped.join}"
  end

  @pos = 0
  do_parse
end

# 白文を解析して、受理した白文（文字列）を返す。構文を確かめるだけなら parse で足りる。
def parse(str)
  parse_tree(str).to_s
end

# ---- 構文木の部品（規則のアクションから呼ぶ）----
def lf(surface, silent = false)
  Kanbun::Tree::Leaf.new(surface, silent: silent)
end

# 再読文字の葉。読みは Lexicon::SAIDOKU から引く。
def lf_saidoku(surface)
  Kanbun::Tree::Leaf.new(surface, saidoku: Kanbun::Lexicon::SAIDOKU.fetch(surface))
end

def seq(*nodes)
  Kanbun::Tree::Seq.new(nodes)
end

def ret(head, *block)
  Kanbun::Tree::Ret.new(head, block)
end

def next_token
  @tokens[@pos].tap { @pos += 1 }
end

# 最長一致トークン化。辞書の表層形を長い順に試すため、
# 「深林」は 1 語、「不亦」は NEG_BU+亦 ではなく FUKI_MATA になる。
def tokenize(str)
  tokens = []
  @skipped = []
  scanner = StringScanner.new(str)
  until scanner.eos?
    if (word = scanner.scan(Kanbun::Lexicon::PATTERN))
      tokens << [Kanbun::Lexicon.token_for(word, scanner), word]
    elsif scanner.scan(Kanbun::Lexicon::PUNCTUATION)
      next
    else
      @skipped << scanner.getch
    end
  end
  tokens << [false, nil]
  tokens
end

---- footer

if __FILE__ == $0
  parser = KanbunParser.new

  tests = [
    # フェーズ1（回帰テスト）
    ["不学",   "不学"],
    ["不読書", "不読書"],
    ["莫笑",   "莫笑"],
    # フェーズ2a：二重否定
    ["無非王土", "無非王土"],   # 王の土地でないものはない
    ["無不陥",   "無不陥"],     # 陥さないものはない
    ["非不慎",   "非不慎"],     # 慎まないのではない
    # フェーズ2a：部分否定
    ["不必賢",   "不必賢"],     # 必ずしも賢いわけではない
    ["不常有",   "不常有"],     # いつもあるとは限らない
    ["不復得",   "不復得"],     # 二度と得られない
    # フェーズ2b：
    ["計莫如植",   "計莫如植"],
    ["地不若人",   "地不若人"],
    ["与易寧戚",   "与易寧戚"],
    ["寧為無為",   "寧為無為"],
    ["馬況人乎",   "馬況人乎"],
    # フェーズ3a
    ["若不成",     "若不成"],
    ["如不成",     "如不成"],
    ["苟無成",     "苟無成"],
    ["学雖無成",   "学雖無成"],
    ["惟士",       "惟士"],
    ["独臣有船",   "独臣有船"],
    # Phase 3b：疑問
    ["学乎",       "学乎"],
    ["学邪",       "学邪"],
    # Phase 3b：反語
    ["豈学哉",     "豈学哉"],
    ["不亦説乎",   "不亦説乎"],
    ["寧有乎",     "寧有乎"],
    ["独学乎",     "独学乎"],
    # Phase 3b：疑問副詞
    ["安在",       "安在"],
    ["何為行",     "何為行"],
    ["何以知",     "何以知"],
    ["如何行",     "如何行"],
    ["孰臣賢",     "孰臣賢"],
    # 回帰確認
    ["馬況人乎",   "馬況人乎"],
  ]

  tests.each do |input, expected|
    result = parser.parse(input)
    status = result == expected ? "OK" : "NG（期待:#{expected}）"
    puts "#{input} => #{result}  #{status}"
  rescue => e
    puts "#{input} => エラー: #{e.message}"
  end
end

