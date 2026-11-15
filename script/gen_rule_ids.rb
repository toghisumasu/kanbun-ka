# frozen_string_literal: true

# 文法 script/kanbun_parser.y の各規則に名前を付けた表 lib/kanbun/rule_ids.rb を作る（Phase 6a 第2段）。
#   ruby script/gen_rule_ids.rb          # lib/kanbun/rule_ids.rb を書く
#   ruby script/gen_rule_ids.rb --check  # 表が .y と一致しているか確かめる（違えば exit 1）
#
# 規則 N（Racc の _reduce_N の N。.y の規則の出現順、1 から）の名前は「左辺/右辺の記号を空白でつないだもの」。
# 例：verb_phrase/NOUN NOUN。.y は変更しない。規則の中身を変えたら名前が変わる（確認済み印が外れる）。
module GenRuleIds
  Y_PATH = File.expand_path('kanbun_parser.y', __dir__)
  OUT_PATH = File.expand_path('../lib/kanbun/rule_ids.rb', __dir__)

  # [[N, 名前, 行末コメント], ...]
  def self.parse(path = Y_PATH)
    lines = File.readlines(path, chomp: true)
    start = lines.index { |l| l == 'rule' } or raise 'rule 節が見つかりません'
    stop = lines.index { |l| l.start_with?('---- header') } or raise 'header 節が見つかりません'
    lhs = nil
    rules = []
    lines[(start + 1)...stop].each do |line|
      next if line.strip.empty? || line.strip.start_with?('#') || line.strip == ';' || line.strip == 'end'

      if line =~ /\A  (\w+)\s*\z/
        lhs = Regexp.last_match(1)
      elsif line =~ /\A\s+[:|]\s*(.*?)\s*(\{.*)?\z/ && lhs
        rhs = Regexp.last_match(1)
        comment = line[/\}\s*#\s*(.+)\z/, 1]
        rules << ["#{lhs}/#{rhs.split.join(' ')}", comment]
      end
    end
    rules.each_with_index.map { |(name, comment), i| [i + 1, name, comment] }
  end

  def self.render(rules)
    body = rules.map { |n, name, comment| "  #{n} => [#{name.inspect}, #{comment.inspect}]" }.join(",\n")
    <<~RUBY
      # frozen_string_literal: true

      # 自動生成：ruby script/gen_rule_ids.rb（script/kanbun_parser.y の各規則の名前）。手で直さない。
      module Kanbun
        module RuleIds
          # N（Racc の _reduce_N）=> [規則名, .y の行末コメント]
          TABLE = {
      #{body}
          }.freeze
        end
      end
    RUBY
  end
end

if $PROGRAM_NAME == __FILE__
  text = GenRuleIds.render(GenRuleIds.parse)
  if ARGV.include?('--check')
    exit(File.read(GenRuleIds::OUT_PATH) == text ? 0 : 1)
  else
    File.write(GenRuleIds::OUT_PATH, text)
    puts "規則 #{GenRuleIds.parse.size} 件"
  end
end
