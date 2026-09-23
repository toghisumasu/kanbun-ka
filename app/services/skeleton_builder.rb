# app/services/skeleton_builder.rb
#
# 役割: ParseResult → 漢文白文骨格を生成する
# 出力: 語順が漢文順・構造マーカーは漢字・語彙は日本語原形のまま
# LLMは「語彙の漢字置換のみ」を担う（語順変更は不要）

class SkeletonBuilder
  PARTICLE_TYPES = %i[wa ga wo ni yori].freeze

  def self.call(result)
    new(result).build
  end

  def initialize(result)
    @r = result
  end

  def build
    parts = case @r.sentence_type
            when :existential  then build_existential
            when :adjectival   then build_adjectival
            when :sequential   then build_sequential
            when :comparative  then build_comparative
            else                    build_verbal     # :transitive / :intransitive
            end
    parts << sentence_end_marker
    parts.compact.reject { |p| p.to_s.empty? }.join(" ").strip
  end

  private

  # 有/無 + 存在物 [+ 於 + 場所]
  # 足がない → "無 足"  /  蛇に足がある → "有 足 於 蛇"
  def build_existential
    cop      = @r.negated ? "無" : "有"
    existent = nouns_only(@r.object)
    location = nouns_only(@r.subject)
    parts    = [cop, existent]
    parts   += ["於", location] if location
    parts
  end

  # 主語 [+ 不] + 述語
  # 馬は速くない → "馬 不 速い"
  def build_adjectival
    [nouns_only(@r.subject), ("不" if @r.negated), @r.predicate.base_form]
  end

  # 主語 + V1 + V2 + ... + 目的語  （連動文は動詞を並べる）
  # 王は民を集めて号令した → "王 集める 号令する 民"
  def build_sequential
    [
      nouns_only(@r.subject),
      *(@r.chain || []).map(&:base_form),
      nouns_only(@r.object)
    ]
  end

  # 主語 + 莫如/不若 + 比較基準 + 述語
  # 馬は牛より速い → "馬 莫如 牛 速い"
  # 地は人より優れない → "地 不若 人 優れる"
  def build_comparative
    cop = @r.negated ? "不若" : "莫如"
    [nouns_only(@r.subject), cop, nouns_only(@r.object), @r.predicate.base_form]
  end

  # 動詞文: 使役・受身・通常の3パターンで語順が変わる
  def build_verbal
    if @r.causative
      # 使構文: 主語 使 目的語 [不] 述語
      # 王は人を行かせた → "王 使 人 行く"
      [
        nouns_only(@r.subject), "使",
        nouns_only(@r.object), ("不" if @r.negated),
        @r.predicate.base_form
      ]
    elsif @r.passive
      # 被構文: 主語 被 述語 [於 動作主]
      # 王が臣下に殺された → "王 被 殺す 於 臣下"
      parts = [nouns_only(@r.subject), "被", @r.predicate.base_form]
      parts += ["於", nouns_only(@r.indirect)] if nouns_only(@r.indirect)
      parts
    else
      # 通常: 主語 [不] 述語 目的語 [於 間接]
      parts = [
        nouns_only(@r.subject), ("不" if @r.negated),
        @r.predicate.base_form, nouns_only(@r.object)
      ]
      parts += ["於", nouns_only(@r.indirect)] if nouns_only(@r.indirect)
      parts
    end
  end

  # 文末マーカー（優先順位: 疑問 > 過去）
  def sentence_end_marker
    return "乎" if @r.question
    return "矣" if @r.past
    nil
  end

  def nouns_only(tokens)
    return nil unless tokens
    result = tokens.reject { |t| PARTICLE_TYPES.include?(t.pos_type) }
                   .map(&:base_form).join
    result.empty? ? nil : result
  end
end

