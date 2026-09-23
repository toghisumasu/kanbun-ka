# script/prompt_lang_bench.rb
#
# 目的: qwen2.5:1.5b に対して日本語・英語・中国語の指示を比較する
# 実行: bundle exec ruby script/prompt_lang_bench.rb
#
# 評価基準:
#   PASS  - 漢字のみ・骨格語順に沿っている
#   KANA  - ひらがな・カタカナが残存している
#   EXTRA - 骨格にない語が挿入されている
#   EMPTY - 空文字列が返った

require "net/http"
require "json"

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL      = "qwen2.5:1.5b"

# ---------------------------------------------------------
# テストケース: [骨格, 期待白文]
# ---------------------------------------------------------
CASES = [
  ["私 食べる 林檎",            "我食林檎"],
  ["王 集める 号令する 民 矣",  "王集民而號令矣"],
  ["馬 不 速い",                "馬不速"],
  ["王 使 人 行く 矣",          "王使人行矣"],
  ["私 忘れる 鍵 於 部屋 矣",  "我忘鍵於室矣"],
].freeze

# ---------------------------------------------------------
# プロンプト定義: 日本語・英語・中国語
# ---------------------------------------------------------
def prompt_ja(skeleton)
  <<~P
    日本語と漢文マーカーが混在した骨格を漢文白文に変換してください。
    骨格に準拠した漢字のみ使用すること。

    骨格：私 食べる 林檎
    白文：我食林檎

    骨格：#{skeleton}
    白文：
  P
end

def prompt_en(skeleton)
  <<~P
    Convert the following skeleton into classical Chinese (漢文).
    Replace Japanese verbs, nouns, and adjectives with 1-2 Chinese characters.
    Keep structural markers (不/使/被/有/無/於/矣/乎) as-is.
    Output only the classical Chinese text, no spaces, one line.

    Skeleton: 私 食べる 林檎
    Classical Chinese: 我食林檎

    Skeleton: #{skeleton}
    Classical Chinese:
  P
end

def prompt_zh(skeleton)
  <<~P
    将以下骨架中的日语词汇替换为对应的文言文汉字。
    保持语序和结构标记（不/使/被/有/无/於/矣/乎）不变。
    仅输出汉字，无空格，一行。

    骨架：私 食べる 林檎
    汉文：我食林檎

    骨架：#{skeleton}
    汉文：
  P
end

# ---------------------------------------------------------
# Ollama 呼び出し
# ---------------------------------------------------------
def call_ollama(prompt)
  uri  = URI(OLLAMA_URL)
  body = {
    model:   MODEL,
    prompt:  prompt,
    stream:  false,
    options: { temperature: 0.0, num_predict: 50 }
  }.to_json

  t0       = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  response = Net::HTTP.post(uri, body, "Content-Type" => "application/json")
  elapsed  = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round

  output = JSON.parse(response.body)["response"].to_s
            .gsub(/\s+/, "").strip

  [output, elapsed]
end

# ---------------------------------------------------------
# 評価
# ---------------------------------------------------------
def evaluate(output, expected)
  return "EMPTY" if output.empty?
  return "KANA"  if output.match?(/[\u3041-\u3096\u30A1-\u30F6]/)
  return "PASS"  if output == expected
  "EXTRA(#{output})"
end

# ---------------------------------------------------------
# 実行
# ---------------------------------------------------------
langs = {
  "日本語" => method(:prompt_ja),
  "English" => method(:prompt_en),
  "中文"   => method(:prompt_zh),
}

puts "=" * 72
puts "モデル: #{MODEL}"
puts "=" * 72
printf "%-30s | %-8s | %-8s | %-8s | %s\n",
       "骨格", "日本語", "English", "中文", "期待値"
puts "-" * 72

CASES.each do |skeleton, expected|
  results = langs.transform_values do |builder|
    output, ms = call_ollama(builder.call(skeleton))
    grade = evaluate(output, expected)
    "#{grade}(#{ms}ms)"
  end

  printf "%-30s | %-14s | %-14s | %-14s | %s\n",
         skeleton,
         results["日本語"],
         results["English"],
         results["中文"],
         expected
end

puts "=" * 72
puts "PASS=正解  KANA=仮名残存  EXTRA=余分追加  EMPTY=空"
