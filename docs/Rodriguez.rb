# bnf_parser.rb
# Rodriguez
# Brad Rodriguez "A BNF Parser in FORTH" (1990) のロジックを再現したRubyプロトタイプ

class BNFParser
  attr_reader :tokens, :idx

  def initialize(tokens)
    @tokens = tokens  # パース対象の配列（文字列の文字配列、または品詞タグ配列）
    @idx = 0         # 現在の入力ポインタ
  end

  # =========================================================
  # コアロジック (Rodriguezパーサーの <BNF, |, ;BNF に相当)
  # =========================================================

  # 端末記号 (Terminal) のマッチング
  # 入力が expected と一致すればポインタを進めて true、失敗すれば false
  def term(expected)
    if @idx < @tokens.size && @tokens[@idx] == expected
      @idx += 1
      true
    else
      false
    end
  end

  # 順序・シーケンス (&)
  # ブロック内のルールを順番に評価し、すべて成功すれば true
  # 途中で1つでも失敗したらポインタを復元して false
  def seq
    saved_idx = @idx
    success = yield # ブロックを実行
    unless success
      @idx = saved_idx # バックトラック：ポインタを復元
    end
    success
  end

  # 選択・分岐 (|)
  # rules（Procの配列）を順番に試す
  # 成功した時点で true を返し、失敗したらポインタを戻して次のルールの試行へ
  def alt(*rules)
    saved_idx = @idx
    rules.each do |rule|
      @idx = saved_idx # 各分岐の試行前に入力位置を復元
      return true if rule.call
    end
    false
  end
end

# =========================================================
# 動作検証 1: 簡易文字パース
# 文法: <S> ::= 'a' 'b' | 'a' 'c'
# ('a'の後に'b'が来るか、または'a'の後に'c'が来るパターン)
# =========================================================

def test_char_parser(str)
  parser = BNFParser.new(str.chars)

  # ルール定義
  # <S> ::= 'a' 'b' | 'a' 'c'
  rule_a_b = -> { parser.seq { parser.term('a') && parser.term('b') } }
  rule_a_c = -> { parser.seq { parser.term('a') && parser.term('c') } }

  # <S> の実行 (alt で選択)
  success = parser.alt(rule_a_b, rule_a_c)

  # 全トークンを消費してパース完了したか確認
  success && parser.idx == str.length
end

puts "=== 動作検証 1: 文字パース ==="
puts "'ab' -> #{test_char_parser('ab') ? 'SUCCESS' : 'FAILED'}" # => SUCCESS
puts "'ac' -> #{test_char_parser('ac') ? 'SUCCESS' : 'FAILED'}" # => SUCCESS
puts "'ad' -> #{test_char_parser('ad') ? 'SUCCESS' : 'FAILED'}" # => FAILED
puts "'abc' -> #{test_char_parser('abc') ? 'SUCCESS' : 'FAILED'}" # => FAILED (余分な文字あり)
puts


# =========================================================
# 動作検証 2: 漢文・訓読文の品詞タグ列パース (SVO/SOV)
# MeCabの品詞タグ列を受け取ったイメージ
# =========================================================

class KanbunParser < BNFParser
  # 品詞タグの定数定義
  NOUN = :noun # 名詞
  WA   = :wa   # 助詞（ハ・ガ） -> 主語マーカー
  WO   = :wo   # 助詞（ヲ）     -> 目的語マーカー
  VERB = :verb # 動詞

  # 1. <主語> ::= <名詞> <助詞ハ>
  def subject
    seq { term(NOUN) && term(WA) }
  end

  # 2. <目的語> ::= <名詞> <助詞ヲ>
  def object
    seq { term(WO) ? false : (term(NOUN) && term(WO)) } # 簡易目的語
  end

  # 3. <述語> ::= <動詞>
  def verb
    term(VERB)
  end

  # 4. <SOV文> ::= <主語> <目的語> <述語>  （日本語の語順）
  def sov_sentence
    seq { subject && object && verb }
  end
end

puts "=== 動作検証 2: 漢文品詞タグ列パース ==="

# 入力例: 「我(NOUN) は(WA) 書(NOUN) を(WO) 読(VERB)」
sov_tokens = [:noun, :wa, :noun, :wo, :verb]

parser = KanbunParser.new(sov_tokens)
matched = parser.sov_sentence && parser.idx == sov_tokens.size

if matched
  puts "パース成功: 日本語SOVパターンにマッチしました！"
else
  puts "パース失敗"
end
