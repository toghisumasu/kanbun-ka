class KanbunParser

# ============================================================
# トークン定義
# NEG_MU(無)・NEG_BAKU(莫) は否定・禁止の多義字。
# フェーズ1では出力文字列が同一のため neg_clause に統一し
# reduce/reduce 競合を回避。フェーズ2で文脈判定を追加予定。
# PROHIBIT_MOTSU は削除（不使用トークンだったため）。
# ============================================================
token NEG_BU NEG_FU NEG_HI NEG_MU NEG_BAKU
      PROHIBIT_NAKA
      VERB NOUN

rule
  sentence
    : clause { result = val[0] }

  clause
    : neg_clause      { result = val[0] }
    | prohibit_clause { result = val[0] }
    | verb_phrase     { result = val[0] }

  # ---- 否定句法（句法一覧 no.1〜6） ----
  # 不：食不飽、力不足（no.1）
  # 弗：弗能応也（no.2）
  # 非：若非吾故人乎 / 富貴非吾願（no.3,4）
  # 無：蛇固無足（no.5）
  # 莫：莫能陥也（no.6）
  # ※莫・無 は禁止句法（no.7,9）にも使われるが、
  #   フェーズ1では出力文字列が同形のため否定句法に統一
  neg_clause
    : NEG_BU   verb_phrase { result = "不#{val[1]}" }
    | NEG_FU   verb_phrase { result = "弗#{val[1]}" }
    | NEG_HI   verb_phrase { result = "非#{val[1]}" }
    | NEG_MU   verb_phrase { result = "無#{val[1]}" }
    | NEG_BAKU verb_phrase { result = "莫#{val[1]}" }

  # ---- 禁止句法（句法一覧 no.7〜9） ----
  # 勿：己所不欲、勿施於人（no.8）
  # 莫（no.7）・無（no.9）はフェーズ2で neg_clause から分離予定
  prohibit_clause
    : PROHIBIT_NAKA verb_phrase { result = "勿#{val[1]}" }

  # ---- 動詞句 ----
  # VERB+VERB: 「能食」「敢食」のような助動詞+動詞の連続に対応
  verb_phrase
    : VERB            { result = val[0] }
    | VERB NOUN       { result = "#{val[0]}#{val[1]}" }
    | VERB VERB       { result = "#{val[0]}#{val[1]}" }
    | NOUN            { result = val[0] }

end

---- header
require 'strscan'

---- inner

# ============================================================
# 語彙辞書
# PDFの句法一覧 no.1〜9 の例文に登場する字を収録
# （フェーズ1対象範囲：否定・禁止の基本句法）
# ============================================================

VERBS = %w[
  学 読 書 見 聞 知 行 来 食 飲 思 言 得 去 入 出 為
  能 足 笑 施 敢
]
# 追加字の根拠（PDFの句法一覧より）:
#   能 → no.2「弗能応也」
#   足 → no.5「蛇固無足」
#   笑 → no.7「君莫笑」
#   施 → no.8「勿施於人」
#   敢 → no.9「子無敢食我也」（助動詞扱い、VERB+VERBで「敢食」と連結）

NOUNS = %w[
  人 君 臣 子 民 文 道 国 師 天 地 王 士 物 事
  願
]
# 追加字の根拠:
#   願 → no.4「富貴非吾願」
# ※吾（代名詞）は意図的に未収録:
#   テストケース「非吾願」で 吾 をスキップ → 「非願」を返すのが期待動作

def parse(str)
  @tokens = tokenize(str)
  @pos = 0
  do_parse
end

def next_token
  @tokens[@pos].tap { @pos += 1 }
end

def tokenize(str)
  tokens = []
  scanner = StringScanner.new(str)
  # 否定・禁止字の判定を VERBS/NOUNS より先に行う
  until scanner.eos?
    case
    when scanner.scan(/不/) then tokens << [:NEG_BU,        '不']
    when scanner.scan(/弗/) then tokens << [:NEG_FU,        '弗']
    when scanner.scan(/非/) then tokens << [:NEG_HI,        '非']
    when scanner.scan(/無/) then tokens << [:NEG_MU,        '無']
    when scanner.scan(/莫/) then tokens << [:NEG_BAKU,      '莫']
    when scanner.scan(/勿/) then tokens << [:PROHIBIT_NAKA, '勿']
    when scanner.scan(Regexp.new("[#{VERBS.join}]")) then tokens << [:VERB, scanner.matched]
    when scanner.scan(Regexp.new("[#{NOUNS.join}]")) then tokens << [:NOUN, scanner.matched]
    else scanner.getch  # 辞書未登録の字はスキップ
    end
  end
  tokens << [false, nil]
  tokens
end

---- footer

if __FILE__ == $0
  parser = KanbunParser.new

  # ============================================================
  # フェーズ1 テストケース
  # PDFの句法一覧 no.1〜9 に対応
  # ============================================================
  tests = [
    # [入力,      期待出力,  句法,        備考]
    ['不学',   '不学',   '否定・不', '動詞単体（no.1）'],
    ['不読書', '不読書', '否定・不', '動詞+名詞（no.1）'],
    ['不知道', '不知道', '否定・不', '動詞+名詞（no.1）'],
    ['弗能',   '弗能',   '否定・弗', '能を追加（no.2）'],
    ['非吾願', '非願',   '否定・非', '吾はスキップ、願はNOUN（no.4）'],
    ['無足',   '無足',   '否定・無', '足を追加（no.5）'],
    ['莫笑',   '莫笑',   '禁止・莫', '笑を追加、出力は否定句法と同形（no.7）'],
    ['勿施',   '勿施',   '禁止・勿', '施を追加（no.8）'],
    ['無敢食', '無敢食', '禁止・無', '敢を追加、VERB+VERBで連結（no.9）'],
    ['見人',   '見人',   '動詞句',   '否定なし'],
    ['知道',   '知道',   '動詞句',   '否定なし'],
  ]

  pass_count = 0
  fail_count = 0

  tests.each do |input, expected, kokuho, note|
    begin
      result = parser.parse(input)
      if result == expected
        pass_count += 1
        puts "PASS  #{input.ljust(5)} => #{result.ljust(6)}  [#{kokuho}] #{note}"
      else
        fail_count += 1
        puts "FAIL  #{input.ljust(5)} => #{result.ljust(6)}  期待: #{expected}  [#{kokuho}] #{note}"
      end
    rescue => e
      fail_count += 1
      puts "ERR   #{input.ljust(5)} => #{e.message}  [#{kokuho}] #{note}"
    end
  end

  puts "\n#{pass_count}/#{tests.size} passed" + (fail_count > 0 ? "  (#{fail_count} failed)" : '')
end

