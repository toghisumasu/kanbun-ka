# frozen_string_literal: true

# 字のリストが、白文側（Lexicon）と読み側（Yomi）でどこまでカバーされているかの表を作る（調査3）。
#
#   bin/rails runner script/kanji91_coverage.rb [docs/kanji91.tsv]
#
# 入力：1 行 1 字の TSV（字 TAB 任意のメモ）。空行と # で始まる行は無視する。
# 出力：字 / 白文側（Lexicon の語種。なければ なし）/ 読み側（Yomi のどの表に、どんな種類であるか）/ メモ。
# 読み側の 機能語（render）は、実際に Yomi.render を呼んで MissingEntry にならないことで判定する
# （表の二重管理をしない）。
#
# 入力ファイルは手元のみ。git の管理下にあるファイルを渡されたら、警告して中止する。

require_relative 'lexicon'
require_relative 'tree'
require_relative 'yomi'

module Kanbun
  module KanjiCoverage
    DEFAULT_PATH = 'docs/kanji91.tsv'

    class BadLine < StandardError; end
    class TrackedFile < StandardError; end
    class MissingFile < StandardError; end

    module_function

    def load_tsv(path)
      File.readlines(path, chomp: true).each_with_index.filter_map do |line, i|
        next if line.strip.empty? || line.start_with?('#')

        char, memo = line.split("\t", 2)
        raise BadLine, "#{i + 1} 行目が 1 字ではありません: #{line.inspect}" unless char.to_s.each_char.count == 1

        [char, memo.to_s]
      end
    end

    # path が git の管理下（git ls-files に含まれる）か
    def tracked?(path)
      dir = File.dirname(File.expand_path(path))
      out = IO.popen(['git', '-C', dir, 'ls-files', '--error-unmatch', File.expand_path(path)], err: File::NULL, &:read)
      !out.to_s.strip.empty?
    rescue SystemCallError
      false
    end

    def rows(pairs)
      pairs.map { |char, memo| { char: char, hakubun: hakubun_side(char), yomi: yomi_side(char), memo: memo } }
    end

    def hakubun_side(char)
      Lexicon::TABLE[char]&.to_s || 'なし'
    end

    GODAN_NAMES = Yomi::GODAN.to_h { |key, forms| [forms, "五段 #{key}"] }.freeze
    ADJ_NAMES = { ku: 'ク活用', shiku: 'シク活用', nari: 'ナリ活用' }.freeze

    def yomi_side(char)
      if (verb = Yomi::VERBS[char])
        return "VERBS（#{verb_type(verb[:forms])}／目的語 #{verb[:obj].inspect}・補語 #{verb[:comp].inspect}）"
      end
      return "ADJS（#{ADJ_NAMES.fetch(Yomi::ADJS[char][0])}）" if Yomi::ADJS.key?(char)
      return "ADV_WHOLE（全体の読み #{Yomi::ADV_WHOLE[char]}）" if Yomi::ADV_WHOLE.key?(char)
      return "ADVS（送り仮名 #{Yomi::ADVS[char].inspect}）" if Yomi::ADVS.key?(char)

      probe(char)
    end

    def verb_type(forms)
      return '一段' if forms == Yomi::ICHI
      return 'サ変' if forms == Yomi::SAHEN

      GODAN_NAMES[forms] || "個別活用 #{forms.join('・')}"
    end

    # 表にない字：名詞は読みの情報を持たず助詞を文脈から付ける。機能語は render が扱えるかを実際に呼んで見る。
    def probe(char)
      token = Lexicon::TABLE[char]
      return 'なし' if token.nil?
      return '名詞（読みの表なし・助詞は文脈から付与）' if token == :NOUN

      leaf = Tree::Leaf.new(char, saidoku: Lexicon::SAIDOKU[char])
      Yomi.render([Yomi::Item.new(leaf, false, nil)], 0, { form: :shushi })
      '機能語（render）'
    rescue Yomi::MissingEntry => e
      e.message.start_with?('読みの辞書にありません') ? 'なし' : "機能語（render・条件つき: #{e.message}）"
    rescue StandardError => e
      "なし（#{e.class}）"
    end

    def run(path, out: $stdout)
      raise MissingFile, "字のリストがありません: #{path}（1 行 1 字の TSV。手元のみ・リポジトリには入れない）" unless File.exist?(path)
      if tracked?(path)
        raise TrackedFile, "#{path} は git の管理下にあります。字のリストはリポジトリには入れない方針なので、中止します"
      end

      out.puts %w[字 白文側 読み側 メモ].join("\t")
      rows(load_tsv(path)).each { |r| out.puts [r[:char], r[:hakubun], r[:yomi], r[:memo]].join("\t") }
    end
  end
end
