# app/services/kanbun_parser_service.rb
#
# 役割: 漢文白文 → 訓点付き漢文・書き下し文を生成する
# 実装: Racc パーサー（lib/kanbun/kanbun_parser.tab.rb）で構文木を作り、
#       Kanbun::Kunten で返り点を付け、Kanbun::Kakikudashi で書き下す。
#
#   白文 → KanbunParser#parse_tree → Kanbun::Kunten.annotate → 返り点つき単位列
#        → to_bracket（訓点付き漢文）/ to_aozora（注記つき漢文＝正本）/ Kakikudashi.convert（書き下し）
#
# 解析できない入力（辞書にない字・文法外の語順・返り点を決められない構文）は例外にせず、
# 白文をそのまま返し、status: :unparsed と理由を添える。LLM が書いた白文は
# 辞書の外に出ることが多いので、上流（KanbunTranslatorService）が止まらないようにするため。
#
# 書き下しは Kanbun::Yomi（読み辞書と活用。歴史的仮名遣い）が構文木から作る（Phase 5a M6）。
# 読みの辞書にない語・扱えない句法のときは、返り点で並べ替えた漢字に再読文字の送り仮名だけを
# 付けた暫定の書き下し（Kakikudashi.convert）に戻し、kakikudashi_exact を false にする。
#
# lib/kanbun は Zeitwerk の対象外（生成ファイル kanbun_parser.tab.rb のため）。require で読む。
require Rails.root.join("lib/kanbun/kanbun_parser.tab").to_s
require Rails.root.join("lib/kanbun/kunten").to_s
require Rails.root.join("lib/kanbun/kakikudashi").to_s
require Rails.root.join("lib/kanbun/yomi").to_s
require Rails.root.join("lib/kanbun/fukubun").to_s
require Rails.root.join("lib/kanbun/verified_entries").to_s

class KanbunParserService
  # 返り値
  #   kunten:        訓点付き漢文（返り点を [ ] で付記。例: 我読[二]漢文[一]）
  #   kakikudashi:   書き下し文（歴史的仮名遣い）。kakikudashi_exact が false のときは暫定（漢字を読み順に並べただけ）
  #   kakikudashi_exact: 確かな読みか ＝ tree_ok かつ verified（Phase 6a）
  #   kakikudashi_tree_ok: 従来の exact（Yomi が読みを決められ、かつ復文検査 Kanbun::Fukubun の違反がゼロ）
  #   kakikudashi_verified: 読みに使った辞書項目がすべて確認済み（lib/kanbun/verified_entries.yml）。既定値で補った読みは確認済みにならない
  #   kakikudashi_unverified: 使った項目のうち未確認のもの（項目 ID。「表名:キー」「DEFAULT:種類:字」）
  #   kakikudashi_reasons: exact でない理由（辞書にない語・復文検査の不一致・曖昧な句形・未確認の辞書項目・既定値）
  #   kunten_aozora: 注記つき漢文（正本。Kanbun::Aozora.parse で読み戻せる）
  #   status:        :parsed または :unparsed
  #   error:         nil または解析できなかった理由（文字列）
  def self.call(hakubun)
    new(hakubun).call
  end

  def initialize(hakubun)
    @hakubun = hakubun.to_s.strip
  end

  def call
    tree = KanbunParser.new.parse_tree(@hakubun, strict: true)
    units = Kanbun::Kunten.annotate(tree)
    aozora = Kanbun::Kunten.to_aozora(units)

    kaki, info = kakikudashi(tree, aozora)
    {
      kunten:        Kanbun::Kunten.to_bracket(units),
      kakikudashi:   kaki,
      kakikudashi_exact: info[:exact],
      kakikudashi_tree_ok: info[:tree_ok],
      kakikudashi_verified: info[:verified],
      kakikudashi_unverified: info[:unverified],
      kakikudashi_reasons: info[:reasons],
      kunten_aozora: aozora,
      status:        :parsed,
      error:         nil
    }
  rescue KanbunParser::UnknownCharacters, Racc::ParseError, Kanbun::Kunten::Error => e
    unparsed(e)
  end

  # 確認済みの辞書項目の一覧。specs は差し替える。
  def self.verified_entries
    @verified_entries ||= Kanbun::VerifiedEntries.load
  end

  RULE_COMMENTS = Kanbun::RuleIds::TABLE.values.to_h { |name, comment| [name, comment] }.freeze

  DEFAULT_KINDS = { 'particle' => '助詞を辞書が明示していない', 'form' => '活用形を決める語がない',
                    'cases' => '二名詞の格（cases）を辞書が明示していない' }.freeze

  private

  # [書き下し, 確かな読みか, 理由の一覧]
  #   exact ＝ Yomi が読みを 1 つに決めている（曖昧な句形でない）かつ 復文検査（Kanbun::Fukubun）の違反ゼロ。
  #   復文検査に違反があれば暫定の書き下し（漢字を読み順に並べたもの）に戻し、違反を理由に返す。
  #   曖昧な句形（殺於敵など）も同じく暫定の書き下しに戻し、曖昧な理由を返す（誤読かもしれない読みを返さない）。
  #   どちらも止めずに、暫定出力と理由を返す。
  def kakikudashi(tree, aozora)
    result = Kanbun::Yomi.analyze(tree)
    violations = Kanbun::Fukubun.check(tree, result.text, parts: result.parts)
    problems = violations + result.ambiguities
    unverified = self.class.verified_entries.unverified(result.used_entries)
    tree_ok = problems.empty?
    verified = unverified.empty?
    info = { tree_ok: tree_ok, verified: verified, exact: tree_ok && verified,
             unverified: unverified, reasons: problems + unverified_reasons(unverified) }
    # 読みが決まらない（tree_ok でない）ときは暫定出力。未確認なだけなら、読みはそのまま返し exact:false と理由で知らせる。
    [tree_ok ? result.text : interim(aozora), info]
  rescue Kanbun::Yomi::MissingEntry => e
    [interim(aozora), { tree_ok: false, verified: false, exact: false, unverified: [], reasons: [e.message] }]
  end

  # 未確認の辞書項目と既定値を、根拠が分かる形で理由にする。
  def unverified_reasons(ids)
    ids.map do |id|
      if id.start_with?('FUNC:')
        "未確認の機能語: #{id.delete_prefix('FUNC:')}"
      elsif id.start_with?('RULE:')
        name = id.delete_prefix('RULE:')
        comment = RULE_COMMENTS[name]
        "未確認の規則: #{name}#{"（#{comment}）" if comment}"
      elsif id.start_with?('DEFAULT:')
        _, kind, surface = id.split(':', 3)
        "既定値: #{{ 'particle' => '助詞', 'form' => '活用形', 'cases' => '二名詞の格' }.fetch(kind, kind)}（#{surface}）：#{DEFAULT_KINDS.fetch(kind, kind)}"
      else
        "未確認の辞書項目: #{id}"
      end
    end
  end

  def interim(aozora)
    Kanbun::Kakikudashi.convert(aozora, yomi: false, hiragana: true)
  end

  def unparsed(error)
    {
      kunten:        @hakubun,
      kakikudashi:   @hakubun,
      kakikudashi_exact: false,
      kakikudashi_tree_ok: false,
      kakikudashi_verified: false,
      kakikudashi_unverified: [],
      kakikudashi_reasons: [],
      kunten_aozora: nil,
      status:        :unparsed,
      error:         "#{error.class.name.split('::').last}: #{error.message}"
    }
  end
end
