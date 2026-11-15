# frozen_string_literal: true

# 構文木（Phase 4c）。Racc の各規則が文字列連結の代わりにこの木を返す。
#
# 読む順序を決める部品は 2 つだけ。
#   Seq … 子を左から右へそのまま読む（返り点なし）
#   Ret … head（返って読む語）を、block（後ろに続く語句）より後で読む
#         例: 読漢文 → Ret(読, [漢文])  読む順は 漢文→読
#
# 句法（否定・比較・選択…）は Seq と Ret の組み合わせで書ける。
# 返り点の種類（レ・一二・上下・甲乙）は、この木の入れ子の形から
# Kanbun::Kunten が決める。構文（語順）が返り点を決め、
# 送り仮名は辞書（動詞の格情報）が決める、という役割分担である。
#
# COBOL の比喩: Seq は PERFORM の順次実行、Ret は「子の処理を先に PERFORM してから
# 自分の後処理を行う」入れ子のコントロールブレークに近い。

module Kanbun
  module Tree
    # 構文の読みが 1 つに決まらないとき、パーサーがその節点に理由（文字列）を付ける（Phase 5b）。
    # Yomi は ambiguous な木を exact とは名乗らない。返り点には影響しない。
    module Ambiguous
      attr_accessor :ambiguous
      # この節点を作った文法規則の名前（Kanbun::RuleTrace が付ける。例 verb_phrase/NOUN NOUN）。手で組んだ木では nil。
      attr_accessor :rule
    end

    # 木の中の ambiguous をすべて外す（受身が確定する被の内側など）。
    def self.clear_ambiguous!(node)
      node.ambiguous = nil
      case node
      when Seq then node.children.each { |c| clear_ambiguous!(c) }
      when Ret then (node.block + [node.head]).each { |c| clear_ambiguous!(c) }
      end
      node
    end

    # 木の中の ambiguous の理由を集める。
    def self.ambiguities(node)
      found = []
      found << node.ambiguous if node.ambiguous
      case node
      when Seq then node.children.each { |c| found.concat(ambiguities(c)) }
      when Ret then (node.block + [node.head]).each { |c| found.concat(ambiguities(c)) }
      end
      found.uniq
    end

    # 1 語。surface は 1 字以上（深林・見聞のような辞書語は 1 つの Leaf）。
    # silent は置字（於・于・乎）：位置は占めるが読まない。
    # saidoku は再読文字（未・将・当…）の読みの表（Lexicon::SAIDOKU の値）。
    #   1 度目はその位置で、2 度目は Ret の head として返ってから読む。
    class Leaf
      include Ambiguous
      # role は同じ字の用法を区別する印（書き下しの読みを選ぶためだけに使う。返り点には影響しない）。
      #   :hikyo（A如B）:compare/:compare_neg（莫如・不若）:ukemi/:ukemi_sho（為A所B）:ukemi_mi（見V）
      #   :dneg（不得不・不可不）:ruika_neg/:ruika_adv/:ruika_ji（非徒A而又B）
      attr_reader :surface, :silent, :saidoku, :role

      def initialize(surface, silent: false, saidoku: nil, role: nil)
        @surface = surface
        @silent = silent
        @saidoku = saidoku
        @role = role
      end

      def silent? = @silent
      def saidoku? = !@saidoku.nil?
      def to_s = @surface
    end

    # 左から右へそのまま読む列。
    class Seq
      include Ambiguous
      attr_reader :children

      def initialize(children)
        @children = children
      end

      def to_s = @children.map(&:to_s).join
    end

    # head を block より後で読む。head は Leaf（1 字以上）。
    class Ret
      include Ambiguous
      attr_reader :head, :block

      def initialize(head, block)
        @head = head
        @block = block
      end

      def to_s = @head.to_s + @block.map(&:to_s).join
    end
  end
end
