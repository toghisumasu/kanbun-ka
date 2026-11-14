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

class KanbunParserService
  # 返り値
  #   kunten:        訓点付き漢文（返り点を [ ] で付記。例: 我読[二]漢文[一]）
  #   kakikudashi:   書き下し文（歴史的仮名遣い）。kakikudashi_exact が false のときは暫定（漢字を読み順に並べただけ）
  #   kakikudashi_exact: Yomi で書き下せたか
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

    kaki, exact = kakikudashi(tree, aozora)
    {
      kunten:        Kanbun::Kunten.to_bracket(units),
      kakikudashi:   kaki,
      kakikudashi_exact: exact,
      kunten_aozora: aozora,
      status:        :parsed,
      error:         nil
    }
  rescue KanbunParser::UnknownCharacters, Racc::ParseError, Kanbun::Kunten::Error => e
    unparsed(e)
  end

  private

  # [書き下し, Yomi で書き下せたか]
  def kakikudashi(tree, aozora)
    [Kanbun::Yomi.kakikudashi(tree), true]
  rescue Kanbun::Yomi::MissingEntry
    [Kanbun::Kakikudashi.convert(aozora, yomi: false, hiragana: true), false]
  end

  def unparsed(error)
    {
      kunten:        @hakubun,
      kakikudashi:   @hakubun,
      kakikudashi_exact: false,
      kunten_aozora: nil,
      status:        :unparsed,
      error:         "#{error.class.name.split('::').last}: #{error.message}"
    }
  end
end
