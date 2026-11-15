# frozen_string_literal: true

require 'yaml'
require_relative 'yomi'
require_relative 'rule_ids'

module Kanbun
  # 読みを確認済みの辞書項目の一覧（Phase 6a）。項目 ID は「表名:キー」（Yomi::Result#used_entries）。
  # DEFAULT（既定値で補った読み）は確認済みにできない。一覧にない項目はすべて未確認。
  class VerifiedEntries
    class Invalid < StandardError; end

    DEFAULT_PATH = File.expand_path('verified_entries.yml', __dir__)

    TABLES = {
      'VERBS' => -> { Yomi::VERBS }, 'ADJS' => -> { Yomi::ADJS }, 'ADVS' => -> { Yomi::ADVS },
      'ADV_WHOLE' => -> { Yomi::ADV_WHOLE }, 'SAIDOKU' => -> { Lexicon::SAIDOKU },
      'SAIDOKU_SECOND' => -> { Yomi::SAIDOKU_SECOND },
      # 第2段：辞書の表の外の読みの出どころ。FUNC は render に直書きした機能語、RULE は木を組んだ文法規則。
      'FUNC' => -> { Yomi::FUNC_KEYS.to_h { |k| [k, true] } },
      'RULE' => -> { RuleIds::TABLE.values.to_h { |name, _| [name, true] } }
    }.freeze

    def self.load(path = DEFAULT_PATH)
      data = YAML.safe_load_file(path) || {}
      new(data)
    end

    # table_keys: { '表名' => [キー, ...] }
    def initialize(table_keys = {})
      raise Invalid, "表名ごとのキー配列で書いてください: #{table_keys.inspect}" unless table_keys.is_a?(Hash)

      @ids = []
      table_keys.each do |table, keys|
        raise Invalid, 'DEFAULT（既定値）は確認済みにできません' if table == 'DEFAULT'
        raise Invalid, "知らない表です: #{table}（使える表: #{TABLES.keys.join(' ')}）" unless TABLES.key?(table)
        raise Invalid, "#{table} はキーの配列で書いてください" unless keys.is_a?(Array)

        keys.each do |key|
          raise Invalid, "#{table} に辞書にないキーがあります: #{key}" unless TABLES.fetch(table).call.key?(key)

          @ids << "#{table}:#{key}"
        end
      end
      @ids.freeze
      @set = @ids.to_h { |i| [i, true] }.freeze
    end

    def count = @ids.size

    def verified?(id)
      @set.key?(id)
    end

    # 使った項目 ID のうち未確認のもの（順序を保つ。DEFAULT は常に未確認）
    def unverified(ids)
      Array(ids).reject { |id| verified?(id) }
    end
  end
end
