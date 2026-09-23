class KanbunParser

# トークン定義（フェーズ1 + 部分否定用トークンを追加）
token NEG_BU NEG_FU NEG_HI NEG_MU NEG_BAKU
      PROHIBIT_NAKA
      HITSZU JOU MATA        # 必・常・復（部分否定用）
      VERB NOUN

rule
  sentence
    : clause { result = val[0] }

  clause
    : double_neg_clause  { result = val[0] }   # 二重否定（新規）
    | partial_neg_clause { result = val[0] }   # 部分否定（新規）
    | neg_clause         { result = val[0] }   # 否定（フェーズ1）
    | prohibit_clause    { result = val[0] }   # 禁止（フェーズ1）
    | verb_phrase        { result = val[0] }

  # ---- 二重否定句法（フェーズ2a 新規）----
  # 無非〜：〜でないものはない（全て〜である）
  # 無不〜：〜しないものはない（全て〜する）
  # 非不〜：〜しないのではない（〜しないわけではない）
  double_neg_clause
    : NEG_MU NEG_HI verb_phrase { result = "無非#{val[2]}" }
    | NEG_MU NEG_BU verb_phrase { result = "無不#{val[2]}" }
    | NEG_HI NEG_BU verb_phrase { result = "非不#{val[2]}" }

  # ---- 部分否定句法（フェーズ2a 新規）----
  # 不必〜：必ずしも〜ではない
  # 不常〜：いつも〜とは限らない
  # 不復〜：二度と〜しない
  partial_neg_clause
    : NEG_BU HITSZU verb_phrase { result = "不必#{val[2]}" }
    | NEG_BU JOU    verb_phrase { result = "不常#{val[2]}" }
    | NEG_BU MATA   verb_phrase { result = "不復#{val[2]}" }

  # ---- 否定句法（フェーズ1）----
  neg_clause
    : NEG_BU   verb_phrase { result = "不#{val[1]}" }
    | NEG_FU   verb_phrase { result = "弗#{val[1]}" }
    | NEG_HI   verb_phrase { result = "非#{val[1]}" }
    | NEG_MU   verb_phrase { result = "無#{val[1]}" }
    | NEG_BAKU verb_phrase { result = "莫#{val[1]}" }

  # ---- 禁止句法（フェーズ1）----
  prohibit_clause
    : PROHIBIT_NAKA verb_phrase { result = "勿#{val[1]}" }

  # ---- 動詞句（多義字：VERB+VERB も許容）----
  verb_phrase
    : VERB            { result = val[0] }
    | VERB NOUN       { result = "#{val[0]}#{val[1]}" }
    | VERB VERB       { result = "#{val[0]}#{val[1]}" }
    | NOUN            { result = val[0] }
    | NOUN NOUN       { result = "#{val[0]}#{val[1]}" }
end

---- header
require 'strscan'

---- inner

VERBS = %w[学 読 書 見 聞 知 行 来 食 飲 思 言 得 去 入 出 為 陥 慎 争 賢 有 笑]
NOUNS = %w[人 君 臣 子 民 文 道 国 師 天 地 王 士 物 事 土 寒 言]

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
  until scanner.eos?
    case
    when scanner.scan(/不/) then tokens << [:NEG_BU,        '不']
    when scanner.scan(/弗/) then tokens << [:NEG_FU,        '弗']
    when scanner.scan(/非/) then tokens << [:NEG_HI,        '非']
    when scanner.scan(/無/) then tokens << [:NEG_MU,        '無']
    when scanner.scan(/莫/) then tokens << [:NEG_BAKU,      '莫']
    when scanner.scan(/勿/) then tokens << [:PROHIBIT_NAKA, '勿']
    when scanner.scan(/必/) then tokens << [:HITSZU,        '必']
    when scanner.scan(/常/) then tokens << [:JOU,           '常']
    when scanner.scan(/復/) then tokens << [:MATA,          '復']
    when scanner.scan(Regexp.new("[#{VERBS.join}]")) then tokens << [:VERB, scanner.matched]
    when scanner.scan(Regexp.new("[#{NOUNS.join}]")) then tokens << [:NOUN, scanner.matched]
    else scanner.getch
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
  ]

  tests.each do |input, expected|
    result = parser.parse(input)
    status = result == expected ? "OK" : "NG（期待:#{expected}）"
    puts "#{input} => #{result}  #{status}"
  rescue => e
    puts "#{input} => エラー: #{e.message}"
  end
end

