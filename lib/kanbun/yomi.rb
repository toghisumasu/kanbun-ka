# frozen_string_literal: true

# 構文木から書き下し文を作る（Phase 5a M6）。
#
#   白文 → 構文木 → 【ここ】 → 書き下し（歴史的仮名遣い）
#
# 方針
#   - 実字（名詞・動詞・形容詞・副詞）は漢字＋送り仮名、助字・助動詞はひらがな。
#     ただし 若・如（如かず・若く）・莫・非・無・得・為・所・者・之・其 は、読みに応じて漢字で出す。
#   - 於・于・乎（補語）・矣・焉・接続の而 は書き下しに出ない。補語の助詞（に・より）は、
#     述語の格情報（下の VERBS の case／comp）を、直前の名詞の送り仮名として付ける。
#   - 活用は、読む順の語列を右から左へ処理して決める。各語は「自分が直前の語に要求する形」を
#     demand として次へ渡し、直前の語はそれを受けて活用する（未然形＋ず、連体形＋所 など）。
#   - 辞書にない語・扱えない句法は MissingEntry を送出する。呼び出し側は暫定の書き下しに戻す。
#
# 返り点や読み順は Kanbun::Kunten が決める。ここは読み順に並んだ語に読みを付ける段階。
# 設計の経緯は docs/phase5a-M6-読み辞書の提案.md。

require_relative 'tree'
require_relative 'lexicon'

module Kanbun
  module Yomi
    class MissingEntry < StandardError; end

    # ---- 活用表（語幹の後ろに付く部分。[未然, 連用, 終止, 連体, 已然]）----
    GODAN = {
      ka: %w[か き く く け], ga: %w[が ぎ ぐ ぐ げ], sa: %w[さ し す す せ],
      ta: %w[た ち つ つ て], ba: %w[ば び ぶ ぶ べ], ma: %w[ま み む む め],
      ra: %w[ら り る る れ], ha: %w[は ひ ふ ふ へ], na: %w[な に ぬ ぬ ね]
    }.freeze
    ICHI      = ['', '', 'る', 'る', 'れ'].freeze           # 見る
    SAHEN     = %w[せ し す する すれ].freeze                 # 死す・見聞す
    RAHEN     = %w[ら り り る れ].freeze                     # 有り・在り
    SHIMO_NI  = ->(row) { [row[0], row[0], row[1], "#{row[1]}る", "#{row[1]}れ"].freeze } # 揚ぐ・植う
    FORMS = %i[mizen renyo shushi rentai izen].freeze
    ADJ_ENDINGS = {
      ku:   %w[から く し き けれ], shiku: %w[しから しく し しき しけれ],
      nari: %w[なら に なり なる なれ]
    }.freeze

    # 動詞：表層形 => [活用の表, 補語の助詞 comp, 目的語の助詞 obj, 二名詞の助詞 cases]
    # obj は 述語の直前の名詞（読漢文→漢文を）、comp は 於 の後の名詞（問礼於老子→老子に）。
    # obj／comp を明示しなかったとき（既定の を／に になるとき）は defaults に記録する（Phase 6a。読みは変えない）。
    def self.v(forms, obj: nil, comp: nil, cases: nil)
      defaults = []
      defaults << :obj if obj.nil?
      defaults << :comp if comp.nil?
      { kind: :verb, forms: forms, obj: obj || 'を', comp: comp || 'に', cases: cases, defaults: defaults.freeze }.freeze
    end

    VERBS = {
      '学' => v(GODAN[:ba]), '読' => v(GODAN[:ma]), '書' => v(GODAN[:ka]), '見' => v(ICHI),
      '聞' => v(GODAN[:ka]), '知' => v(GODAN[:ra]), '行' => v(GODAN[:ka], obj: 'に'),
      '食' => v(GODAN[:ha]), '飲' => v(GODAN[:ma]), '思' => v(GODAN[:ha]), '言' => v(GODAN[:ha]),
      '得' => v(['', '', '', 'る', 'れ']), '入' => v(GODAN[:ra], obj: 'に'),
      '為' => v(GODAN[:sa]), '陥' => v(GODAN[:ra]), '慎' => v(GODAN[:ma]), '争' => v(GODAN[:ha]),
      '有' => v(RAHEN, obj: ''), '笑' => v(GODAN[:ha]), '植' => v(SHIMO_NI.call(%w[ゑ う])),
      '買' => v(GODAN[:ha]), '戚' => v(GODAN[:ma]), '易' => v(SHIMO_NI.call(%w[へ ふ])),
      '施' => v(GODAN[:sa]), '成' => v(GODAN[:ra]), '還' => v(GODAN[:ra], obj: 'に'),
      '去' => v(GODAN[:ra]), '帰' => v(GODAN[:ra], obj: 'に'), '習' => v(GODAN[:ha]),
      '在' => v(RAHEN, obj: 'に'), '好' => v(GODAN[:ma]), '教' => v(GODAN[:ha], cases: %w[に を]),
      '問' => v(GODAN[:ha]), '揚' => v(SHIMO_NI.call(%w[げ ぐ]), cases: %w[を に]),
      '待' => v(GODAN[:ta]), '省' => v(%w[み み みる みる みれ]), '及' => v(GODAN[:ba]),
      '登' => v(GODAN[:ra], obj: 'に'), '照' => v(GODAN[:ra]), '随' => v(GODAN[:ha]),
      '潤' => v(GODAN[:sa]), '重' => v(SHIMO_NI.call(%w[ね ぬ])), '怕' => v(SHIMO_NI.call(%w[れ る])),
      '欹' => v(GODAN[:ta]), '聴' => v(GODAN[:ka]), '撥' => v(GODAN[:ha]), '看' => v(ICHI),
      '起' => v(SHIMO_NI.call(%w[き く])), '喜' => v(GODAN[:ba]), '飛' => v(GODAN[:ba]),
      '満' => v(GODAN[:ta]), '話' => v(GODAN[:sa]), '語' => v(GODAN[:ra]), '炊' => v(GODAN[:ga]),
      '釣' => v(GODAN[:ra]), '命' => v(%w[ぜ じ ず ずる ずれ]), '殺' => v(GODAN[:sa]),
      '敬' => v(GODAN[:ha]), '対' => v(GODAN[:ha]), '害' => v(GODAN[:ha]),
      '見聞' => v(SAHEN), '逃走' => v(SAHEN), '呼吸' => v(SAHEN), '望見' => v(SAHEN),
      # 自動詞
      '開' => v(GODAN[:ka]), '啼' => v(GODAN[:ka]), '鳴' => v(GODAN[:ka]), '咲' => v(GODAN[:ka]),
      '流' => v(SHIMO_NI.call(%w[れ る])), '死' => v(SAHEN), '出' => v(SHIMO_NI.call(%w[で づ])),
      '来' => v(GODAN[:ra]), '走' => v(GODAN[:ra]), '興' => v(GODAN[:ra]), '滅' => v(GODAN[:ba]),
      '吹' => v(GODAN[:ka]), '降' => v(GODAN[:ra]), '生' => v(SAHEN)
    }.freeze

    # 形容詞：表層形 => [活用型, 漢字のあとの送り仮名の語幹]。ク活用・シク活用・ナリ活用。
    ADJS = {
      '賢' => [:ku, ''], '敏' => [:ku, ''], '説' => [:shiku, 'ば'], '大' => [:ku, 'ほ'],
      '小' => [:ku, 'さ'], '高' => [:ku, ''], '深' => [:ku, ''], '長' => [:ku, ''],
      '多' => [:ku, ''], '少' => [:ku, 'な'], '美' => [:shiku, ''], '明' => [:nari, 'らか'],
      '紫' => [:nari, ''], '紅' => [:nari, ''], '猛' => [:ku, ''], '白' => [:ku, ''],
      '青' => [:ku, ''], '赤' => [:ku, ''], '短' => [:ku, ''], '清' => [:ku, ''],
      '楽' => [:shiku, ''], '黒' => [:ku, ''], '泰' => [:nari, 'らか'], '冷' => [:ku, 'た'],
      '愚' => [:nari, 'か'], '貧' => [:shiku, ''], '新' => [:shiku, ''], '疾' => [:ku, ''],
      '衆' => [:ku, ''], '寡' => [:ku, 'な']
    }.freeze

    # 副詞：表層形 => 読み添え（送り仮名）
    ADVS = {
      '皆' => '', '甚' => 'だ', '最' => 'も', '倶' => 'に', '既' => 'に', '嘗' => 'て', '亦' => 'た',
      '又' => 'た', '但' => 'だ', '暗' => 'に', '潜' => 'かに', '細' => 'かに',
      '散' => '', '能' => 'く', '乃' => 'ち', '即' => 'ち', '遂' => 'に',
      '卒' => 'に', '已' => 'に', '漸' => 'く', '尽' => 'く', '妄' => 'りに', '忽' => 'ち',
      '蓋' => 'し', '具' => 'に', '敢' => 'へて', '数' => 'ば', '必' => 'ずしも', '常' => 'には',
      '復' => 'た'
    }.freeze

    # 副詞のうち、読みが表層形に送り仮名を足すだけでは書けないもの：表層形 => 全体の読み（漢字も含む）。
    # ADVS の送り仮名に漢字を入れると表層形と二重に出る（何独 => 'ぞ独り' は 何独ぞ独り になる）。
    ADV_WHOLE = {
      '何独' => '何ぞ独り'
    }.freeze

    # 再読文字（Lexicon::SAIDOKU の 1 度目の読みは送り仮名つきでそのまま使う）。2 度目の読み：
    #   表層形 => [形（終止, 連体）, 直前の語への要求 demand]
    SAIDOKU_SECOND = {
      '未' => [%w[ず ざる], { form: :mizen }],
      '将' => [%w[んとす んとする], { form: :mizen }],
      '当' => [%w[べし べき], { form: :shushi }],
      '応' => [%w[べし べき], { form: :shushi }],
      '宜' => [%w[べし べき], { form: :shushi }],
      '須' => [%w[べし べき], { form: :shushi }],
      '猶' => [%w[ごとし ごとき], { form: :rentai, vpart: 'が', npart: 'の' }],
      '盍' => [%w[ざる ざる], { form: :mizen }]
    }.freeze

    # 読みを render に直書きしている機能語（辞書の表にない）。used_entries には FUNC:<字> で記録する（Phase 6a 第2段）。
    # role で読みが分かれるものは FUNC:<字>@<role>、置字の 乎 は FUNC:乎@silent。
    FUNC_CHARS = %w[不 弗 可 而 矣 焉 也 乎 哉 邪 於 于 所 者 則 若 非 無 莫 勿 使 令 被 自 従 与 其].freeze
    FUNC_ROLES = %i[ruika_adv ruika_neg ruika_ji hikyo compare compare_neg ukemi ukemi_mi dneg].freeze

    # 代名詞の主語（は を付ける）
    PRONOUNS = %w[我 吾 汝 彼 私 此 是].freeze

    # 書き下しの 1 語。tree の葉に、読む順での位置と、木から決まる助詞を持たせる。
    Item = Struct.new(:leaf, :second, :npart) do
      def surface = leaf.surface
      def role = leaf.role
    end

    # 項目ごとの出力：構文木の葉（読む順での 1 語）と、その書き下し断片。
    Piece = Struct.new(:leaf, :second, :text)

    module_function

    # text: 書き下し／ambiguities: 読みが 1 つに決まらない句形（パーサーが木に付けた理由）。
    # 書き下しが白文と矛盾しないかは Kanbun::Fukubun が別に検査する（Yomi の自己申告にしない）。
    # parts: 項目ごとの出力 [Piece]（読む順。つなぐと text になる）。Fukubun が項目単位の検査に使う。
    # used_entries: 読みを作るのに使った辞書項目の ID（「表名:キー」。既定値で補ったときは「DEFAULT:種類:字」）。名詞は対象外。
    Result = Struct.new(:text, :ambiguities, :parts, :used_entries) do
      # Yomi が「読みは 1 つに決まる」と確信しているか（exact の必要条件。十分条件ではない）
      def exact? = ambiguities.empty?
    end

    # 構文木 → 書き下し（String）。扱えない語・句法は MissingEntry。
    def kakikudashi(tree)
      analyze(tree).text
    end

    # 書き下しと、曖昧な句形の一覧。
    def analyze(tree)
      (result, used) = collecting do
        items = collect(tree)
        out = Array.new(items.size, '')
        demand = { form: :shushi }
        (items.size - 1).downto(0) do |i|
          out[i], demand = render(items, i, demand)
        end
        add_topic!(items, out)
        parts = items.each_with_index.map { |it, i| Piece.new(it.leaf, it.second, out[i]) }
        [out.join, parts]
      end
      Result.new(result[0], ambiguities(tree), result[1], used)
    end

    # ブロックの間に引いた辞書項目の ID を集める。[ブロックの値, ID の配列（重複なし）] を返す。
    def collecting
      outer = Thread.current[:yomi_used]
      Thread.current[:yomi_used] = []
      value = yield
      [value, Thread.current[:yomi_used].uniq]
    ensure
      Thread.current[:yomi_used] = outer
    end

    # 辞書項目の使用を記録する（collecting の外では何もしない）。
    def note(id)
      Thread.current[:yomi_used]&.push(id)
    end

    # ---- 曖昧な句形 ----
    # 読みが 1 つに決まらない構文は、パーサーが木に ambiguous を付けてある（Kanbun::Tree.ambiguities）。
    # 受身が確定している形（見V・被V・為A所B）には付かない。
    def ambiguities(tree)
      Tree.ambiguities(tree)
    end

    # ---- 読む順の語列を作る（再読文字は 2 度、1 度目と 2 度目）----
    def collect(tree)
      items = []
      walk(tree, items, {}.compare_by_identity)
      items
    end

    def walk(node, items, case_of)
      case node
      when Tree::Leaf then items << Item.new(node, false, case_of[node])
      when Tree::Seq then node.children.each { |c| walk(c, items, case_of) }
      when Tree::Ret
        items << Item.new(node.head, false, nil) if node.head.saidoku?
        assign_cases(node.head, node.block, case_of)
        node.block.each { |c| walk(c, items, case_of) }
        items << Item.new(node.head, node.head.saidoku?, nil)
      end
    end

    # 述語の格情報で、block の名詞（葉）に付ける助詞を case_of に記録する。
    def assign_cases(head, block, case_of)
      cases = head_cases(head, block)
      return if cases.nil?

      obj_idx = 0
      after_prep = false
      block.each do |child|
        next unless child.is_a?(Tree::Leaf)

        if child.silent?
          after_prep = true
        elsif noun_like?(child, head)
          kind = after_prep ? :comp : (cases[:list] ? :list : :obj)
          case_of[child] =
            if after_prep then cases[:comp]
            elsif cases[:list] then cases[:list][obj_idx]
            else cases[:obj]
            end
          note_default_particle(head, kind, obj_idx)
          obj_idx += 1
        end
      end
    end

    # 動詞が助詞を明示していないのに、その既定の助詞を名詞に付けたとき DEFAULT:particle を記録する。
    def note_default_particle(head, kind, obj_idx)
      verb = VERBS[head.surface]
      return unless verb && head.role.nil?

      defaults = verb[:defaults]
      used_default =
        case kind
        when :comp then defaults.include?(:comp)
        when :obj then defaults.include?(:obj)
        else # 二名詞：1 つ目の「の」は直書き（cases の定めがなければ）、2 つ目は obj（cases があれば明示）
          note('FUNC:二名詞の') if obj_idx.zero? && verb[:cases].nil?
          obj_idx == 1 ? defaults.include?(:obj) && verb[:cases].nil? : false
        end
      note("DEFAULT:particle:#{head.surface}") if used_default
    end

    # 名詞。辞書が動詞にしている字（書・言）でも、動詞の目的語の位置に来れば名詞として扱う（読書 → 書を読む）
    def noun_like?(leaf, head)
      return true if Lexicon::TABLE[leaf.surface] == :NOUN
      return false unless VERBS.key?(head.surface) && head.role.nil? && leaf.role.nil?

      Lexicon::TABLE[leaf.surface] == :VERB
    end

    # 述語ごとの助詞。名詞の補語（於 の後ろ）は comp、直後は obj（二名詞なら cases の順）。
    def head_cases(head, block)
      nouns = block.count { |c| c.is_a?(Tree::Leaf) && !c.silent? && noun_like?(c, head) }
      case head.role
      when :ukemi then return { obj: 'の', comp: 'の' }
      when :hikyo then return { obj: 'の', comp: 'の' }
      when :compare then return { obj: 'に', comp: 'に' }
      end
      case head.surface
      when '非' then { obj: 'に', comp: 'に' }
      when '使', '令' then { obj: 'をして', comp: 'をして' }
      when '無', '有', '莫' then { obj: '', comp: 'に' }
      else
        verb = VERBS[head.surface]
        if verb
          list = nouns == 2 && block.none? { |c| c.is_a?(Tree::Leaf) && c.silent? } ? (verb[:cases] || ['の', verb[:obj]]) : nil   # 名詞が 2 つで述語に二重格の定めがなければ 故郷の事を
          { obj: verb[:obj], comp: verb[:comp], list: list }
        elsif ADJS.key?(head.surface) then { obj: '', comp: 'より' }
        end
      end
    end

    # ---- 1 語の描画。(文字列, 直前の語への要求) を返す ----
    # demand: { form:, vpart:（動詞・助動詞に付く助詞）, npart:（名詞に付く助詞）, suffix: }
    def render(items, idx, dem)
      it = items[idx]
      note_func(it)
      case it.role
      when :ruika_adv then return ruika_adv(it, dem)
      when :ruika_neg then return ruika_neg(it, dem)
      when :ruika_ji  then return ['、而も', { form: :shushi }]
      when :hikyo     then return hikyo(it, dem)
      when :compare   then return compare_verb(it, dem)
      when :compare_neg then return compare_neg(it, dem)
      when :ukemi     then return ukemi_i(it, dem)
      when :ukemi_mi  then return ['る', { form: :mizen }]
      when :dneg      then return dneg(items, idx, dem) if it.surface != '不'
      end
      surf = it.surface

      return saidoku(it, dem) if it.leaf.saidoku?

      case surf
      when '不', '弗' then aux_neg(items, idx, dem)
      when '可' then aux_form(dem, '', %w[べし べき], { form: :shushi }, mizen: 'べから', renyo: 'べく')
      when '而' then ['', { form: :renyo, suffix: 'て' }]
      when '矣', '焉' then ['', { form: :shushi }]
      when '也' then aux_form(dem, '', %w[なり なる], { form: :rentai })
      when '乎' then it.leaf.silent? ? ['', dem] : aux_form(dem, '', %w[や や], { form: :shushi })
      when '哉' then aux_form(dem, '', %w[かな かな], { form: :shushi })
      when '邪' then aux_form(dem, '', %w[か か], { form: :shushi })
      when '於', '于' then ['', dem]
      when '所' then wrap(dem, '所', { form: :rentai })
      when '者' then wrap(dem, '者', { form: :rentai })
      when '則' then ['則ち' + dem[:vpart].to_s, { form: :izen, vpart: 'ば' }]
      when '若'
        # 仮定の 若：若A則B だけ読む（若A のみは ずんば の形になるため未対応）
        raise MissingEntry, '若A（則なし）の ずんば は未対応です' unless items.any? { |i| i.surface == '則' }

        ['若し', { form: :renyo }]
      when '非' then render_hi(it, dem)
      when '無', '莫' then render_nashi(dem, surf)
      when '勿' then wrap(dem, '勿かれ', { form: :rentai, suffix: 'こと' })
      when '使', '令' then aux_form(dem, '', %w[しむ しむる], { form: :mizen }, mizen: 'しめ', renyo: 'しめ')
      when '被' then aux_form(dem, '', %w[る らる], { form: :mizen })
      when '自', '従' then ['', { form: :renyo, npart: 'より' }]
      when '与' then ['', { form: :renyo, npart: 'と' }]
      when '其' then ['其の', { form: :renyo }]
      else
        render_content(items, idx, dem)
      end
    end

    # 直書きの機能語の読みを使うとき、項目 ID を記録する。
    def note_func(item)
      if FUNC_ROLES.include?(item.role)
        note("FUNC:#{item.surface}@#{item.role}")
      elsif !item.leaf.saidoku? && FUNC_CHARS.include?(item.surface)
        note("FUNC:#{item.surface}#{'@silent' if item.surface == '乎' && item.leaf.silent?}")
      end
    end

    def it_part(item, dem)
      item.npart || dem[:npart] || ''
    end

    # 助動詞・助字：直前から決まる活用（dem[:form]）で表示を選ぶ
    def aux_form(dem, _prefix, shushi_rentai, own_demand, mizen: nil, renyo: nil)
      form = dem[:form] || :shushi
      text =
        case form
        when :mizen then mizen || shushi_rentai[0]
        when :renyo then renyo || shushi_rentai[0]
        when :rentai then shushi_rentai[1]
        else shushi_rentai[0]
        end
      [text + dem[:vpart].to_s + dem[:suffix].to_s, own_demand]
    end

    def wrap(dem, text, own_demand)
      [text + dem[:vpart].to_s + dem[:suffix].to_s, own_demand]
    end

    # 不・弗：未然形に付く。次が 可・得 のとき ざる、不知非恥 型は ざるは
    def aux_neg(items, idx, dem)
      nxt = items[idx + 1]
      form = dem[:form] || :shushi
      part = ''
      if nxt && %w[可 得].include?(nxt.surface) && nxt.role == :dneg then form = :rentai
      elsif nxt && noun?(nxt) && items[idx + 2]&.surface == '非'
        form = :rentai
        part = 'は'
      end
      text = { rentai: 'ざる', izen: 'ざれ', shushi: 'ず', renyo: 'ず', mizen: 'ざら' }.fetch(form, 'ず')
      [text + part + dem[:vpart].to_s + dem[:suffix].to_s, { form: :mizen }]
    end

    def render_hi(_item, dem)
      form = dem[:form] || :shushi
      text = { rentai: '非ざる', izen: '非ざれ', shushi: '非ず', renyo: '非ず' }.fetch(form, '非ず')
      [text + dem[:vpart].to_s + dem[:suffix].to_s, { form: :rentai, vpart: 'に', npart: 'に' }]
    end

    def render_nashi(dem, surf)
      form = dem[:form] || :shushi
      text = surf + { shushi: 'し', rentai: 'き', renyo: 'く', izen: 'けれ', mizen: 'から' }.fetch(form, 'し')
      [text + dem[:vpart].to_s + dem[:suffix].to_s, { form: :rentai }]
    end

    # 其の疾きこと…：其 のあとの用言は連体形＋こと
    def nominalized?(items, idx)
      idx.positive? && items[idx - 1].surface == '其'
    end

    def noun?(item)
      Lexicon::TABLE[item.surface] == :NOUN && item.leaf.role.nil?
    end

    # 実字：名詞・動詞・形容詞・副詞
    def render_content(items, idx, dem)
      it = items[idx]
      surf = it.surface
      token = Lexicon::TABLE[surf]
      if it.npart
        [surf + it.npart, { form: :renyo }]
      elsif ADJS.key?(surf)
        conjugate_adj(items, idx, dem)
      elsif VERBS.key?(surf)
        conjugate_verb(items, idx, dem)
      elsif token == :NOUN
        [surf + it_part(it, dem), { form: :renyo }]
      elsif ADV_WHOLE.key?(surf)
        note("ADV_WHOLE:#{surf}")
        [ADV_WHOLE[surf], { form: :renyo }]
      elsif ADVS.key?(surf)
        note("ADVS:#{surf}")
        [surf + ADVS[surf], { form: :renyo }]
      else
        raise MissingEntry, "読みの辞書にありません: #{surf}"
      end
    end

    def form_for(items, idx, dem)
      return [:rentai, 'こと'] if nominalized?(items, idx) && dem[:form] != :mizen

      note("DEFAULT:form:#{items[idx].surface}") if dem[:form].nil?
      [dem[:form] || :shushi, nil]
    end

    def conjugate_verb(items, idx, dem)
      surf = items[idx].surface
      form, suffix = form_for(items, idx, dem)
      note("VERBS:#{surf}")
      ending = VERBS.fetch(surf)[:forms][FORMS.index(form) || 2]
      [surf + ending + suffix.to_s + dem[:vpart].to_s + dem[:suffix].to_s, verb_demand(items, idx, dem)]
    end

    def verb_demand(_items, _idx, _dem)
      { form: :renyo }
    end

    # 為A所B の 為：Aの Bする所と為る
    def ukemi_i(_item, dem)
      form = dem[:form] || :shushi
      ['為' + GODAN[:ra][FORMS.index(form) || 2] + dem[:vpart].to_s, { form: :rentai, vpart: 'と' }]
    end

    # 不得不・不可不：得（え）と べし。不 は aux_neg が 次が 可・得 のとき ざる にする
    def dneg(items, idx, dem)
      it = items[idx]
      form = dem[:form] || :shushi
      if it.surface == '得'
        ['得' + ['', '', '', 'る', 'れ'][FORMS.index(form) || 2], { form: :rentai, vpart: 'を' }]
      else
        text = { mizen: 'べから', renyo: 'べく', rentai: 'べき' }.fetch(form, 'べし')
        [text, { form: :shushi }]
      end
    end

    def conjugate_adj(items, idx, dem)
      surf = items[idx].surface
      note("ADJS:#{surf}")
      type, stem = ADJS.fetch(surf)
      form, suffix = form_for(items, idx, dem)
      ending = ADJ_ENDINGS.fetch(type)[FORMS.index(form) || 2]
      [surf + stem + ending + suffix.to_s + dem[:vpart].to_s + dem[:suffix].to_s, { form: :renyo }]
    end

    # 再読文字：1 度目は送り仮名つき、2 度目は 直前の活用を要求する助動詞
    def saidoku(item, dem)
      r = item.leaf.saidoku
      unless item.second
        note("SAIDOKU:#{item.surface}")
        okuri = r[:okuri].tr('ァ-ヶ', 'ぁ-ゖ')
        return [item.surface + okuri, { form: :renyo }]
      end

      note("SAIDOKU_SECOND:#{item.surface}")
      forms, own = SAIDOKU_SECOND.fetch(item.surface)
      text = dem[:form] == :rentai ? forms[1] : forms[0]
      [text + dem[:vpart].to_s + dem[:suffix].to_s, own]
    end

    # 比況 A如B：Bの ごとし、A（用言）が ごとし
    def hikyo(item, dem)
      forms = %w[ごとし ごとき]
      text = dem[:form] == :rentai ? forms[1] : forms[0]
      [text + dem[:vpart].to_s + dem[:suffix].to_s, { form: :rentai, vpart: 'が', npart: 'の' }]
    end

    # 比較 莫如・不若：如 は 如く／如か（Bに 如かず）。如・若 は漢字
    def compare_verb(item, dem)
      forms = GODAN[:ka]
      form = dem[:form] || :shushi
      ending = forms[FORMS.index(form) || 2]
      [item.surface + ending + dem[:vpart].to_s + dem[:suffix].to_s, { form: :renyo, npart: 'に', vpart: 'に' }]
    end

    def compare_neg(item, dem)
      if item.surface == '不'
        aux_neg([item], 0, dem)
      else
        [render_nashi(dem, '莫')[0], { form: :shushi, vpart: 'は' }]
      end
    end

    # 累加：徒だに／唯だに／独り … のみに非ず／のみならず
    def ruika_adv(item, dem)
      text = { '徒' => '徒だに', '唯' => '唯だに', '独' => '独り' }.fetch(item.surface)
      [text, { form: :renyo }]
    end

    def ruika_neg(item, dem)
      if item.surface == '非'
        text = '非ず'
        part = 'のみに'
      else
        text = 'ならず'
        part = 'のみ'
      end
      [text + dem[:vpart].to_s, { form: :rentai, vpart: part }]
    end

    # 主題の は：先頭が代名詞、または 比況・比較・受身・非・也 を含む文の先頭名詞
    def add_topic!(items, out)
      first = items.first
      return unless first && Lexicon::TABLE[first.surface] == :NOUN && first.leaf.role.nil?
      return if first.npart || out[0] != first.surface   # 助詞がすでに付いている

      nominal = items.any? { |i| %i[hikyo compare ukemi].include?(i.role) || i.surface == '非' }
      return unless PRONOUNS.include?(first.surface) || (nominal && items.size > 1)

      note('FUNC:主題は')
      out[0] = out[0] + 'は'
    end
  end
end
