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
    keyword_init: true
  )

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
    hakubun  = call_ollama(build_prompt(@input, skeleton))

    # Step 5: Raccパーサー → 訓点・書き下し文
    kunten_result = KanbunParserService.call(hakubun)

    Result.new(
      hakubun:     hakubun,
      kunten:      kunten_result[:kunten],
      kakikudashi: kunten_result[:kakikudashi],
      skeleton:    skeleton,
      fallback:    fallback
    )
  end

  private

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

        原文：#{original}
        骨格：#{skeleton}
        白文：
      PROMPT
    else
      <<~PROMPT
        以下の現代日本語を漢文の白文に変換してください。
        出力は白文のみ・空白なし・1行。

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

