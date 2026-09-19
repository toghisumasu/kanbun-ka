# app/services/kanbun_translator_service.rb
require 'net/http'
require 'json'
require 'uri'

class KanbunTranslatorService
  OLLAMA_URL = ENV.fetch('OLLAMA_URL')
  MODEL      = ENV.fetch('OLLAMA_MODEL')

  # 中国語プロンプト＋《白氏文集》スタイル指定で品質向上
  SYSTEM_PROMPT = <<~CHINESE.freeze
    你是一位精通古典汉文的翻译专家，专门将现代日语翻译成文言文。
    翻译时请参考《白氏文集》的文体风格。
    只输出文言文原文，不输出任何解释、假名、标注或多余标点。
  CHINESE

  MAX_RETRIES  = 3
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 30

  def self.call(japanese_text)
    new(japanese_text).translate
  end

  def initialize(japanese_text)
    @text = japanese_text
  end

  def translate
    attempt = 0
    begin
      extract_content(request_ollama)
    rescue => e
      attempt += 1
      retry if attempt < MAX_RETRIES
      raise "Ollamaエラー（#{MAX_RETRIES}回試行後）: #{e.message}"
    end
  end

  private

  def request_ollama
    uri  = URI(OLLAMA_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    req.body = payload.to_json
    http.request(req)
  end

  def payload
    {
      model:    MODEL,
      think:    false,   # ← 必須。falseにしないと30秒超
      stream:   false,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user',   content: @text }
      ]
    }
  end

  def extract_content(res)
    raise "HTTP #{res.code}: #{res.message}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body).dig('message', 'content')&.strip
  end
end
