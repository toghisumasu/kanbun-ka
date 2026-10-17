require "open3"
require "net/http"
require "json"

class KanbunTranslatorService
  OLLAMA_URL   = "http://localhost:11434/api/generate".freeze
  OLLAMA_MODEL = "qwen3:8b".freeze

  Result = Struct.new(
    :hakubun,      # 漢文白文
    :kunten,       # 訓点付き漢文
    :kakikudashi,  # 書き下し文
    :skeleton,     # SkeletonBuilder出力（デバッグ用）
    :fallback,     # true = BNFパース失敗でLLM全文委譲
    :parse_error,  # nil = 訓点付与に成功 / 文字列 = Raccパーサーが解析できなかった理由
    :retried,      # true = LLM の出力が白文でなかった（仮名混じりなど）ため 1 回だけ再生成した
    keyword_init: true
  )

  # 白文として受け入れる形：漢字と句読点だけ。仮名・英数字・空白・説明文を含むものは白文ではない。
  HAKUBUN_PATTERN = /\A[\p{Han}、。]+\z/

  # LLM に渡す書き方の約束と見本。見本は Racc パーサーが解析できる形だけを選ぶ
  # （LLM が見本の文体に寄るほど、後段の返り点付与が成功しやすい）。
  HAKUBUN_RULES = <<~RULES.freeze
    【白文の書き方（厳守）】
    ・漢字だけで書く。ひらがな・カタカナ・英数字・空白・説明は一切書かない
    ・語順は 主語＋述語＋目的語。助詞（は・が・を・に・の・て）は書かない
    ・否定は 不・非・無・勿 を述語の直前に置く
    ・活用語尾（ぶ・しい・く）を残さず、語幹の漢字だけにする
    例）原文：彼は書を読まない → 白文：彼不読書
    例）原文：月は明るく風は清い → 白文：月明風清
    例）原文：君子は道を学ぶ → 白文：君子学道
    例）原文：茶を飲んで書を読む → 白文：飲茶読書
    例）原文：彼は君子ではない → 白文：彼非君子
  RULES

  def self.call(japanese_text)
    new(japanese_text).call
  end

  def initialize(japanese_text)
    @input = japanese_text.strip
  end

  def call
    # Step 1: 形態素解析
    tokens = MeCabAdapter.call(run_mecab(@input))

    # Step 2: 構文解析（失敗してもnil、例外は出さない）
    parse_result = KanbunBNFParser.new(tokens).parse

    # Step 3: 骨格生成
    skeleton = parse_result ? SkeletonBuilder.call(parse_result) : nil

    # Step 4: LLM → 漢文白文
    fallback = skeleton.nil?
    prompt   = build_prompt(@input, skeleton)
    hakubun  = normalize(call_ollama(prompt))

    # Step 4b: 白文でない出力（仮名混じりなど）は、見本つきで 1 回だけ作り直す
    retried = false
    if retry_needed?(hakubun)
      retried = true
      hakubun = normalize(call_ollama(build_retry_prompt(prompt, hakubun)))
    end

    # Step 5: Raccパーサー → 訓点・書き下し文
    kunten_result = KanbunParserService.call(hakubun)

    Result.new(
      hakubun:     hakubun,
      kunten:      kunten_result[:kunten],
      kakikudashi: kunten_result[:kakikudashi],
      skeleton:    skeleton,
      fallback:    fallback,
      parse_error: kunten_result[:error],
      retried:     retried
    )
  end

  private

  # LLM の出力を白文の形に整える：最初の 1 行だけ取り、空白を除く。
  def normalize(raw)
    return raw unless raw.is_a?(String)

    raw.lines.first.to_s.delete(" 　\t\r\n")
  end

  # 文字列で、空でなく、白文の形でないときだけ作り直す（nil・空は作り直しても変わらない）。
  def retry_needed?(hakubun)
    hakubun.is_a?(String) && !hakubun.empty? && !hakubun.match?(HAKUBUN_PATTERN)
  end

  def build_retry_prompt(prompt, previous)
    <<~PROMPT
      #{prompt}
      【前回の出力】#{previous}
      前回の出力には漢字と句読点以外の文字が含まれていました。
      上の「白文の書き方」と例に従い、漢字だけで書き直してください。白文のみ・1行。
      白文：
    PROMPT
  end

  # ---------------------------------------------------------
  # MeCab 呼び出し（Open3でシェルインジェクション対策）
  # ---------------------------------------------------------
  def run_mecab(text)
    stdout, _stderr, status = Open3.capture3("mecab", stdin_data: text)
    raise "MeCab failed: #{_stderr}" unless status.success?
    stdout
  end

  # ---------------------------------------------------------
  # LLMプロンプト: 骨格ありとなしで切り替える
  # ---------------------------------------------------------
  def build_prompt(original, skeleton)
    if skeleton
      # 骨格に実際に含まれるマーカーだけ抽出
      all_markers  = %w[不 使 被 有 無 莫如 不若 於 矣 乎]
      used_markers = all_markers.select { |m| skeleton.include?(m) }
      marker_note  = used_markers.empty? ? "なし" : used_markers.join(" ")

      <<~PROMPT
        あなたは漢文（文言文）の専門家です。
        骨格の語順・構造マーカーを保持したまま、語彙を漢字に置換してください。

        【骨格に含まれるマーカー（そのまま保持）】#{marker_note}
        【置換対象】名詞・動詞・形容詞（日本語原形 → 漢字1〜2字）
        【厳守】骨格に準拠した漢字のみ使用すること
        【出力形式】白文のみ・空白なし・1行

        #{HAKUBUN_RULES}
        原文：#{original}
        骨格：#{skeleton}
        白文：
      PROMPT
    else
      <<~PROMPT
        以下の現代日本語を漢文の白文に変換してください。
        出力は白文のみ・空白なし・1行。

        #{HAKUBUN_RULES}
        原文：#{original}
        白文：
      PROMPT
    end
  end

  # ---------------------------------------------------------
  # Ollama 呼び出し
  # ---------------------------------------------------------
  def call_ollama(prompt)
    uri  = URI(OLLAMA_URL)
    body = {
      model:   OLLAMA_MODEL,
      prompt:  prompt,
      stream:  false,
      think:   false,
      options: { temperature: 0.0, num_predict: 200 }
    }.to_json

    response = Net::HTTP.post(uri, body, "Content-Type" => "application/json")
    JSON.parse(response.body)["response"].strip
  end
end
