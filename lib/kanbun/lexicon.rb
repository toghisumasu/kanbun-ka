# frozen_string_literal: true

# 漢文白文のトークン辞書（Phase 4a）。
#
# 役割
#   表層形（1 字または複数字）→ 文法のトークン名 の対応表を持ち、
#   トークナイザーが「最長一致」で切り出せるようにする。
#   以前は script/kanbun_parser.y の中で、1 字ごとの when 節と
#   VERBS / NOUNS の文字クラスで切っていたため、
#   「深林」「漢文」などの複数字語を 1 語として扱えなかった。
#
# 方針（kanbun-ka 構文・訓点設計.md §2 より）
#   - 熟語の ①主述 ②修飾 ③並列 ④対立 と、接尾・畳語は 1 トークンとして登録する。
#   - ⑤補足（読書・開業・帰郷…）と ⑥認定（不運・無断・非常…）は登録しない。
#     文中では分解して解析し、返り点を付けるため。
#   - 品詞（VERB / NOUN / ADJ）は暫定。多義字の確定は Phase 5 以降。
#
# 辞書を足すときの注意
#   - 同じ表層形を複数の品詞に入れると、先に登録した方が勝つ（VERB → NOUN → ADJ の順）。
#     意図した重複は spec/lib/kanbun/lexicon_spec.rb の OVERLAPS に書く。
#   - トークン名は script/kanbun_parser.y の token 宣言にあるものだけ使える
#     （lexicon_spec が自動検査する）。

module Kanbun
  module Lexicon
    # 機能語（句法のトークン）。表層形 → トークン名。
    FUNCTION_WORDS = {
      '不亦' => :FUKI_MATA,
      '何為' => :GI_NANSURU, '何以' => :GI_NANMOTE,
      '何如' => :GI_IKANI_A, '如何' => :GI_IKANI_B,
      '莫如' => :MOKU_NAKU,  '莫若' => :MOKU_SHIKA,
      '不若' => :FUSHIKA,    '不如' => :FUNYUU,
      '与' => :YO_NIMO, '寧' => :NAMU, '況' => :IWA_N_YA,
      '不' => :NEG_BU, '弗' => :NEG_FU, '非' => :NEG_HI, '無' => :NEG_MU, '莫' => :NEG_BAKU,
      '勿' => :PROHIBIT_NAKA,
      '必' => :HITSZU, '常' => :JOU, '復' => :MATA,
      '若' => :KATEN_SHIKA, '如' => :KATEN_NYO, '苟' => :KATEN_IYA,
      '雖' => :KATEN_IEDOMO, '縦' => :KATEN_TATOI,
      '惟' => :GENTEI_YUI, '独' => :GENTEI_DOKU,
      '豈' => :HAN_AI, '安' => :GI_AN, '誰' => :GI_DARE, '孰' => :GI_IZURE, '何' => :GI_NANI,
      '乎' => :SHI_KO, '哉' => :SHI_SAI, '邪' => :SHI_JA,
      # 置字（補語マーカー）。乎 は下の token_for で文末助字と区別する
      '於' => :PREP, '于' => :PREP
    }.freeze

    # 1 字の内容語（従来の VERBS / NOUNS をそのまま移した。回帰を避けるため中身は変えない）
    VERBS = %w[学 読 書 見 聞 知 行 来 食 飲 思 言 得 入 出 為 陥 慎 争 賢 有 笑
               植 買 戚 易 施 成 還 去 帰 習 敏 説 在 好
               教 問 揚].freeze
    NOUNS = %w[人 君 臣 子 民 文 道 国 師 天 地 王 士 物 事 土 寒 言 計 馬 船
               我 吾 汝 山 水 花 鳥 虎 礼 名 籍 豚 景 霜].freeze

    # 自動詞（Phase 4b）。目的語を取らないので「花開鳥啼」を 花|開|鳥|啼 と切れる。
    # 既存の VERBS は回帰を避けるためそのまま。自動詞への移動は動詞の格情報辞書（Phase 5）で行う。
    VERBS_I = %w[開 啼 鳴 咲 飛 流].freeze

    # 形容詞（Phase 4a で追加）。賢・敏・慎・好 などは回帰テストのため VERB のまま。
    # 述語としての扱いは Phase 4b（基本構文 5 文型）で見直す。
    ADJS = %w[大 小 高 深 長 多 少 美 明 紫 紅 猛 白 青 赤].freeze

    # 複数字語。設計書 §2 の例＋Phase 4a の確認語。
    COMPOUND_NOUNS = %w[
      深林 漢文 老子 兵法 二月花
      大国 明月 飛鳥 水門 美女
      風雨 兄弟 妻子 草木
      善悪 陰陽 遠近 興亡 盛衰
      地震 日没 雷鳴 鶏鳴 年長
      孔子 君子 聖人 後世 返景 苛政 霜葉 項梁 陽貨
    ].freeze
    COMPOUND_VERBS = %w[見聞 逃走 呼吸].freeze

    # 表層形 → トークン名。先に入れた品詞が優先（言 は VERB）。
    TABLE = begin
      table = FUNCTION_WORDS.dup
      { VERB: VERBS + COMPOUND_VERBS,
        VERB_I: VERBS_I,
        NOUN: NOUNS + COMPOUND_NOUNS,
        ADJ: ADJS }.each do |token, words|
        words.each { |word| table[word] ||= token }
      end
      table.freeze
    end

    # 最長一致のためのパターン。Regexp.union は与えた順に試すので、長い語を先に並べる。
    PATTERN = Regexp.union(TABLE.keys.sort_by { |word| [-word.size, word] }).freeze

    # 辞書の品詞に加え、乎 だけは次の語で役割が変わる。
    #   乎 + 名詞 …… 置字（補語マーカー。霜葉紅乎…）→ :PREP
    #   乎 + それ以外／文末 …… 疑問・反語の文末助字 → :SHI_KO
    # LR(1) は 1 トークン先までしか見ず、同じトークンの次がどちらかは決められないため、
    # トークナイザーで 1 語先読みして別トークンにする。
    def self.token_for(word, scanner)
      token = TABLE.fetch(word)
      return token unless word == '乎'

      nxt = scanner.check(PATTERN)
      nxt && TABLE[nxt] == :NOUN ? :PREP : token
    end

    # 句読点。トークンにはせず、記録もせずに読み飛ばす。
    PUNCTUATION = /[、。]/

    # 複数の品詞に登録されている表層形（意図しない重複を spec で検出するため）
    def self.overlaps
      all = FUNCTION_WORDS.keys + VERBS + VERBS_I + COMPOUND_VERBS + NOUNS + COMPOUND_NOUNS + ADJS
      all.tally.select { |_word, count| count > 1 }.keys
    end
  end
end
