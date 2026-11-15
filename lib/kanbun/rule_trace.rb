# frozen_string_literal: true

require_relative 'tree'
require_relative 'rule_ids'
require_relative 'kanbun_parser.tab'

module Kanbun
  # Racc が生成した各規則の動作 _reduce_N を包み、その規則が新しく作った木の節点に規則名を付ける（Phase 6a 第2段）。
  #
  #   - script/kanbun_parser.y は変更しない。解析の結果（木の形・返り点・読み）も変えない。
  #   - 通過だけの規則（result = val[0]）は、すでに規則名のある節点を返すので上書きしない（||=）。
  #   - 規則名は Kanbun::RuleIds::TABLE（script/gen_rule_ids.rb が .y から作る）で _reduce_N の N から引く。
  module RuleTrace
    NODE_CLASSES = [Tree::Leaf, Tree::Seq, Tree::Ret].freeze

    def self.tag(result, name)
      nodes = result.is_a?(Array) ? result : [result]
      nodes.each { |node| node.rule ||= name if NODE_CLASSES.any? { |k| node.is_a?(k) } }
      result
    end

    # _reduce_N を持つ KanbunParser に、規則名を付ける包みを prepend する。
    def self.install!(parser = ::KanbunParser)
      return if parser.ancestors.any? { |m| m.instance_variable_defined?(:@rule_trace) }

      wrapper = Module.new
      wrapper.instance_variable_set(:@rule_trace, true)
      RuleIds::TABLE.each do |n, (name, _comment)|
        method = :"_reduce_#{n}"
        wrapper.send(:define_method, method) do |val, values, result|
          RuleTrace.tag(super(val, values, result), name)
        end
      end
      parser.prepend(wrapper)
    end
  end
end

Kanbun::RuleTrace.install!
