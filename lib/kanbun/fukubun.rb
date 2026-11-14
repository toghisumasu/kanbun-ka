# frozen_string_literal: true

# 復文検査（Phase 5b S2）。白文（構文木）と書き下しを比べ、矛盾を理由の配列で返す。
#
#   白文 → 構文木 → 返り点（Kunten）→ 読む順（Reorder）  ┐
#                                                          ├→ 比較 → 違反の理由（なければ []）
#   書き下し（Yomi など、どこで作ったものでもよい）        ┘
#
# 検査する 4 項目
#   1. 実字（名詞・動詞・形容詞・副詞）の漢字が全部残っている（置き字は数えない）
#   2. 再読文字が 2 度出る（1 度目の漢字と、2 度目の読み）
#   3. 返り点を適用した順（Kanbun::Reorder）と、書き下しの実字の並びが一致する
#   4. 字の重複がない
#   （S5 で追加）5. 置き字が書き下しに出ていない（累加の「、而も」は例外）
#
# 書き下しを作る側（Yomi）の自己申告ではなく、白文と書き下しだけから判定する。
# 助詞・活用の正しさは見ない。語の取りこぼし・重複・順序の取り違えを検出する検査である。
#
# 置き字・実字の定義は Lexicon（OKIJI_TOKENS・CONTENT_TOKENS）。ここには持たない。

require_relative 'tree'
require_relative 'lexicon'
require_relative 'kunten'
require_relative 'reorder'

module Kanbun
  module Fukubun
    module_function

    # 見V の 見 は受身の助動詞（殺さる）で、漢字は書き下しに出ない。実字に数えない。
    FUNCTION_ROLES = %i[ukemi_mi].freeze

    # tree: 白文の構文木（KanbunParser#parse_tree の結果）／kakikudashi: 書き下し（String）
    # 戻り値: 違反の理由（String）の配列。違反がなければ空。
    # parts: Yomi::Result#parts（項目ごとの葉と断片）。あれば項目単位の検査（6）も行う。
    def check(tree, kakikudashi, parts: nil)
      leaves = leaves_of(tree)
      jitsuji = jitsuji_chars(leaves)
      units = Kunten.annotate(tree)
      expected = Reorder.reorder(units).reject { |u| silent?(u) }.map(&:kanji).select { |c| jitsuji.include?(c) }
      actual = kakikudashi.each_char.select { |c| jitsuji.include?(c) }

      reasons = count_reasons(jitsuji, expected, actual)
      reasons << order_reason(expected, actual) if reasons.empty? && expected != actual
      reasons.concat(saidoku_reasons(leaves, kakikudashi))
      reasons.concat(okiji_reasons(leaves, kakikudashi))
      reasons.concat(part_reasons(parts, kakikudashi, reasons)) if parts
      reasons.compact
    end

    # 実字の字（読まない置き字・機能語・受身の 見 は含まない）
    def jitsuji_chars(leaves)
      leaves.select { |leaf| jitsuji?(leaf) }.flat_map { |leaf| leaf.surface.each_char.to_a }.uniq
    end

    def jitsuji?(leaf)
      token = Lexicon::TABLE[leaf.surface]
      !leaf.silent? && !FUNCTION_ROLES.include?(leaf.role) &&
        Lexicon::CONTENT_TOKENS.include?(token) && !Lexicon::OKIJI_TOKENS.include?(token)
    end

    # 1・4: 字ごとの出現回数を比べる
    def count_reasons(jitsuji, expected, actual)
      jitsuji.flat_map do |c|
        e = expected.count(c)
        a = actual.count(c)
        if a < e then ["字の欠落: #{c}"]
        elsif a > e then ["字の重複: #{c}"]
        else []
        end
      end
    end

    # 3: 回数が合っているのに順序が違う
    def order_reason(expected, actual)
      "読み順の不一致: 期待 #{expected.join} / 実際 #{actual.join}"
    end

    # 2: 再読文字は、1 度目の漢字のあとに 2 度目の読み（Lexicon::SAIDOKU の saidoku）が続く
    def saidoku_reasons(leaves, kakikudashi)
      leaves.select(&:saidoku?).map(&:surface).uniq.filter_map do |c|
        stem = Lexicon::SAIDOKU.fetch(c)[:saidoku].tr('ァ-ヶ', 'ぁ-ゖ')
        idx = kakikudashi.index(c)
        next "再読文字が2度出ていない: #{c}" if idx.nil? || !kakikudashi[(idx + 1)..].to_s.include?(stem)
      end
    end

    # 5（phase5a の検査の復活）: 置き字（読まない字）が書き下しに出ていない。
    # 例外は 累加の 而（:ruika_ji）で、「、而も」と読む。ほかに同じ字を読む語があれば、その分は許す。
    def okiji_reasons(leaves, kakikudashi)
      silent = leaves.select { |l| l.silent? && l.role != :ruika_ji }.flat_map { |l| l.surface.each_char.to_a }.uniq
      silent.filter_map do |c|
        allowed = leaves.count { |l| (!l.silent? || l.role == :ruika_ji) && l.surface.include?(c) }
        "置き字が書き下しに出ている: #{c}" if kakikudashi.count(c) > allowed
      end
    end

    # 与A・自A・従A は字そのものを出さず、助詞（と・より）が直前の名詞の送り仮名になる
    PARTICLE_ONLY = %w[与 自 従].freeze

    # 6（phase5a の項目検査の復活）: Yomi の項目ごとの断片を使う。
    #   - 読む字（機能語）が断片ごと落ちていない（与・自・従は例外）
    #   - 実字の断片に、その漢字が残っている（別の位置に同じ字があっても通さない）
    #   - 断片をつないだものが、渡された書き下しと一致する
    def part_reasons(parts, kakikudashi, found)
      reasons = []
      reasons << "書き下しと項目の断片が一致しません" if parts.map(&:text).join != kakikudashi
      parts.each do |pc|
        leaf = pc.leaf
        next if leaf.silent?

        if pc.text.empty?
          next if PARTICLE_ONLY.include?(leaf.surface)
          next if jitsuji?(leaf) && leaf.surface.each_char.any? { |c| found.include?("字の欠落: #{c}") } # 1 で報告済み

          reasons << "#{jitsuji?(leaf) ? '実字' : '機能語'}の欠落: #{leaf.surface}"
        elsif jitsuji?(leaf) && leaf.role.nil? && !leaf.saidoku? && !in_order?(leaf.surface, pc.text)
          reasons << "実字の位置: #{leaf.surface}"
        end
      end
      reasons.uniq
    end

    # 断片に、表層形の字が順に（間に送り仮名を挟んでよい）残っている。何独 => 何ぞ独り も通す。
    def in_order?(surface, text)
      return true if text.start_with?(surface)

      pos = 0
      surface.each_char.all? { |c| (pos = text.index(c, pos)) && (pos += 1) }
    end

    # ---- 内部 ----
    def leaves_of(node)
      case node
      when Tree::Leaf then [node]
      when Tree::Seq then node.children.flat_map { |c| leaves_of(c) }
      when Tree::Ret then leaves_of(node.head) + node.block.flat_map { |c| leaves_of(c) }
      else []
      end
    end

    def silent?(unit)
      unit.yomi&.hidden? && unit.yomi.text.empty?
    end

    private_class_method :leaves_of, :silent?, :in_order?
  end
end
