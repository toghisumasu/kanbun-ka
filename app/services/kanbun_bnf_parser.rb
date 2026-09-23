# app/services/kanbun_bnf_parser.rb

class KanbunBNFParser

  # ---------------------------------------------------------
  # Token・定数
  # ---------------------------------------------------------
  Token = Struct.new(:surface, :pos_type, :base_form, keyword_init: true)

  NOUN     = :noun
  PRON     = :pron
  WA       = :wa
  GA       = :ga
  WO       = :wo
  NI       = :ni
  VERB     = :verb
  ADJ      = :adj
  ADJV     = :adjv
  NEG      = :neg
  ARU      = :aru
  NAI_ADJ  = :nai_adj
  PASSIVE  = :passive
  CAUS     = :causative
  PAST     = :past
  CONJ_TE  = :conj_te
  YORI     = :yori
  QUESTION = :question

  # ---------------------------------------------------------
  # ParseResult
  # initialize は override しない。
  # 全 ParseResult.new 呼び出しで chain:/question: を明示する。
  # ---------------------------------------------------------
  ParseResult = Struct.new(
    :subject, :object, :indirect, :predicate,
    :chain, :question,
    :negated, :passive, :causative, :past, :sentence_type,
    keyword_init: true
  ) do
    PARTICLE_TYPES = %i[wa ga wo ni yori].freeze

    def to_kanbun_hint
      parts = case sentence_type
              when :existential
                cop = negated ? "無" : "有"
                [].tap do |p|
                  p << "#{cop}構文"
                  p << "存在物: #{nouns_only(object)}"      if object
                  p << "場所/所有: #{nouns_only(subject)}"  if subject
                end
              when :adjectival
                [].tap do |p|
                  p << "形容詞文"
                  p << "主語: #{nouns_only(subject)}"       if subject
                  p << "#{"不＋" if negated}述語: #{predicate.base_form}"
                end
              when :sequential
                [].tap do |p|
                  p << "主語: #{nouns_only(subject)}"        if subject
                  p << "連動: #{(chain || []).map(&:base_form).join("→")}"
                  p << "目的語: #{nouns_only(object)}"       if object
                  p << "[過去・完了]"                         if past
                end
              when :comparative
                cop = negated ? "不若（及ばない）" : "莫如（が最良）"
                [].tap do |p|
                  p << "比較文(#{cop})"
                  p << "主語: #{nouns_only(subject)}"        if subject
                  p << "比較基準: #{nouns_only(object)}"
                  p << "#{"不＋" if negated}述語: #{predicate.base_form}"
                end
              else
                [].tap do |p|
                  p << "主語: #{nouns_only(subject)}"               if subject
                  p << "[使役 → 使構文]"                            if causative
                  p << "[受身 → 被構文]"                            if passive
                  p << "#{"不＋" if negated}述語: #{predicate.base_form}"
                  p << "目的語: #{nouns_only(object)}"              if object
                  p << "に格（→ 於/給）: #{nouns_only(indirect)}"  if indirect
                  p << "[過去・完了]"                                if past
                end
              end
      parts << "【疑問 → 乎/哉】" if question
      parts.join(" / ")
    end

    private

    def nouns_only(tokens)
      return "" unless tokens
      tokens.reject { |t| PARTICLE_TYPES.include?(t.pos_type) }
            .map(&:surface).join
    end
  end

  # ---------------------------------------------------------
  # コンストラクタ
  # ---------------------------------------------------------
  def initialize(tokens)
    @tokens = tokens
    @idx    = 0
  end

  def parse
    @idx   = 0
    result = sentence_rule
    (result && @idx == @tokens.size) ? result : nil
  end

  private

  # ---------------------------------------------------------
  # コアプリミティブ
  # ---------------------------------------------------------
  def term(*pos_types)
    t = @tokens[@idx]
    return nil unless t && pos_types.include?(t.pos_type)
    @idx += 1
    t
  end

  def seq
    saved  = @idx
    result = yield
    unless result
      @idx = saved
      return nil
    end
    result
  end

  def alt(*rules)
    saved = @idx
    rules.each do |rule|
      @idx = saved
      r    = rule.call
      return r if r
    end
    nil
  end

  def optional(&blk)
    saved  = @idx
    result = blk.call
    @idx   = saved unless result
    result
  end

  # ---------------------------------------------------------
  # 部品ルール
  # ---------------------------------------------------------
  def noun_tokens
    ts = []
    while (t = term(NOUN, PRON))
      ts << t
    end
    ts.empty? ? nil : ts
  end

  def subject_phrase
    seq do
      ns = noun_tokens;  break nil unless ns
      m  = term(WA, GA); break nil unless m
      ns + [m]
    end
  end

  def object_phrase
    seq do
      ns = noun_tokens; break nil unless ns
      m  = term(WO);    break nil unless m
      ns + [m]
    end
  end

  def indirect_phrase
    seq do
      ns = noun_tokens; break nil unless ns
      m  = term(NI);    break nil unless m
      ns + [m]
    end
  end

  # ---------------------------------------------------------
  # 文タイプ別ルール
  # ---------------------------------------------------------
  def existential_sentence
    seq do
      owner = optional { indirect_phrase }
      nouns = noun_tokens; break nil unless nouns
      ga    = term(GA);    break nil unless ga

      pred_info = alt(
        -> { seq { t = term(ARU);     break nil unless t; { token: t, negated: false } } },
        -> { seq { t = term(NAI_ADJ); break nil unless t; { token: t, negated: true  } } }
      )
      break nil unless pred_info

      _past = optional { term(PAST) }

      ParseResult.new(
        subject: owner, object: nouns + [ga], indirect: nil,
        predicate: pred_info[:token], negated: pred_info[:negated],
        passive: false, causative: false, past: !!_past,
        chain: nil, question: false,
        sentence_type: :existential
      )
    end
  end

  def adjectival_sentence
    seq do
      subj  = optional { subject_phrase }
      pred  = term(ADJ, ADJV); break nil unless pred
      neg   = optional { term(NEG) }
      _past = optional { term(PAST) }

      ParseResult.new(
        subject: subj, object: nil, indirect: nil,
        predicate: pred, negated: !!neg,
        passive: false, causative: false, past: !!_past,
        chain: nil, question: false,
        sentence_type: :adjectival
      )
    end
  end

  def sequential_sentence
    seq do
      subj  = optional { subject_phrase }
      obj   = optional { object_phrase }
      indir = optional { indirect_phrase }

      chain = []
      loop do
        v = term(VERB); break unless v
        chain << v
        te = term(CONJ_TE); break unless te
      end
      break nil if chain.size < 2

      neg   = optional { term(NEG) }
      _past = optional { term(PAST) }

      ParseResult.new(
        subject: subj, object: obj, indirect: indir,
        predicate: chain.last, chain: chain,
        negated: !!neg, passive: false, causative: false,
        past: !!_past, question: false,
        sentence_type: :sequential
      )
    end
  end

  def comparative_sentence
    seq do
      subj     = optional { subject_phrase }
      standard = noun_tokens; break nil unless standard
      yori     = term(YORI);  break nil unless yori
      pred     = term(ADJ, ADJV, VERB); break nil unless pred
      neg      = optional { term(NEG) }
      _past    = optional { term(PAST) }

      ParseResult.new(
        subject: subj, object: standard + [yori], indirect: nil,
        predicate: pred, negated: !!neg,
        passive: false, causative: false, past: !!_past,
        chain: nil, question: false,
        sentence_type: :comparative
      )
    end
  end

  def verbal_sentence
    seq do
      subj  = optional { subject_phrase }
      obj   = optional { object_phrase }
      indir = optional { indirect_phrase }
      pred  = term(VERB); break nil unless pred
      caus  = optional { term(CAUS) }
      pass  = optional { term(PASSIVE) }
      neg   = optional { term(NEG) }
      _past = optional { term(PAST) }

      ParseResult.new(
        subject: subj, object: obj, indirect: indir,
        predicate: pred, negated: !!neg,
        passive: !!pass, causative: !!caus, past: !!_past,
        chain: nil, question: false,
        sentence_type: obj ? :transitive : :intransitive
      )
    end
  end

  def sentence_rule
    r = alt(
      -> { existential_sentence },
      -> { adjectival_sentence },
      -> { sequential_sentence },
      -> { comparative_sentence },
      -> { verbal_sentence }
    )
    return nil unless r

    q = optional { term(QUESTION) }
    r.question = !q.nil?
    r
  end
end

