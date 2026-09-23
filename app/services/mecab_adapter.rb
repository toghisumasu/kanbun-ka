# app/services/mecab_adapter.rb
#
# MeCab（IPA辞書）出力 → KanbunBNFParser::Token配列 変換

class MeCabAdapter
  # フィールドインデックス（IPA辞書）
  F_POS   = 0   # 品詞
  F_SUB1  = 1   # 品詞細分類1
  F_BASE  = 6   # 原形

  # mecab_adapter.rb の call メソッドを修正
  def self.call(mecab_output)
    raw = mecab_output.split("\n")
              .reject { |l| l.start_with?("EOS") || l.strip.empty? }
              .filter_map { |l| build_token(l) }
    raw = merge_shimau_pattern(raw)   # ① てしまう を除去
    raw = merge_suru_verbs(raw)       # ② サ変動詞を統合
    merge_compound_verbs(raw)         # ③ 複合動詞を統合
  end

  # ① て + しまう → 両方除去（完了は直後のたが担う）
  private_class_method def self.merge_shimau_pattern(tokens)
    result = []
    i = 0
    while i < tokens.size
      t      = tokens[i]
      next_t = tokens[i + 1]
      if t.pos_type == KanbunBNFParser::CONJ_TE &&
         next_t&.pos_type == KanbunBNFParser::VERB &&
         next_t&.base_form == "しまう"
        i += 2  # te + shimau をスキップ
      else
        result << t
        i += 1
      end
    end
    result
  end

  # ③ 連続するVERBを複合動詞として統合
  private_class_method def self.merge_compound_verbs(tokens)
    result = []
    i = 0
    while i < tokens.size
      t      = tokens[i]
      next_t = tokens[i + 1]
      if t.pos_type == KanbunBNFParser::VERB &&
         next_t&.pos_type == KanbunBNFParser::VERB
        merged = KanbunBNFParser::Token.new(
          surface:   t.surface + next_t.surface,
          pos_type:  KanbunBNFParser::VERB,
          base_form: next_t.base_form   # 後の動詞を基本形として使用
        )
        result << merged
        i += 2
      else
        result << t
        i += 1
      end
    end
    result
  end

  # 「名詞-サ変接続」+「する/した/し+助動詞」→ 単一VERBに統合
  private_class_method def self.merge_suru_verbs(tokens)
    result = []
    i = 0
    while i < tokens.size
      t = tokens[i]
      # サ変接続名詞の次がsuru動詞なら結合
      if t.pos_type == KanbunBNFParser::NOUN &&
         tokens[i + 1]&.pos_type == KanbunBNFParser::VERB &&
         %w[する くる].include?(tokens[i + 1].base_form)

        merged = KanbunBNFParser::Token.new(
          surface:   t.surface + tokens[i + 1].surface,
          pos_type:  KanbunBNFParser::VERB,
         base_form: t.base_form + "する"
        )
        result << merged
        i += 2
      else
        result << t
        i += 1
      end
    end
    result
  end

  private_class_method def self.build_token(line)
    surface, feat_str = line.split("\t", 2)
    return nil unless feat_str

    f       = feat_str.split(",")
    pos     = f[F_POS]
    sub1    = f[F_SUB1]
    base    = f[F_BASE] || surface
    pos_type = classify(pos, sub1, base, surface)
    return nil unless pos_type   # 助詞「の」「と」など未対応品詞はスキップ

    KanbunBNFParser::Token.new(surface: surface, pos_type: pos_type, base_form: base)
  end

  private_class_method def self.classify(pos, sub1, base, surface)
    case pos
    when "名詞"
      case sub1
      when "代名詞"        then KanbunBNFParser::PRON
      when "形容動詞語幹"  then KanbunBNFParser::ADJV
      else                      KanbunBNFParser::NOUN
      end
    when "助詞"
      case surface
      when "は"        then KanbunBNFParser::WA
      when "が"        then KanbunBNFParser::GA
      when "を"        then KanbunBNFParser::WO
      when "に"        then KanbunBNFParser::NI
      when "より"      then KanbunBNFParser::YORI
      when "て"
        sub1 == "接続助詞" ? KanbunBNFParser::CONJ_TE : nil
      when "か", "や"
        sub1 == "終助詞" ? KanbunBNFParser::QUESTION : nil
      end
    when "動詞"
      %w[ある いる].include?(base) ? KanbunBNFParser::ARU : KanbunBNFParser::VERB
    when "形容詞"
      base == "ない" ? KanbunBNFParser::NAI_ADJ : KanbunBNFParser::ADJ
    when "助動詞"
      case base
      when "ない", "ぬ", "ず"  then KanbunBNFParser::NEG
      when "れる", "られる"    then KanbunBNFParser::PASSIVE
      when "せる", "させる"    then KanbunBNFParser::CAUS
      when "た", "だ"          then KanbunBNFParser::PAST
      end
    end
  end
end

