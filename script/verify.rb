# frozen_string_literal: true

# RSpec が使えない環境向けの簡易検証。spec/support/kanbun_fixtures.rb の全ケースと、
# spec/lib/kanbun/aozora_spec.rb と同じ構造チェックを素の Ruby で実行する。
#   使い方: ruby script/verify.rb   （LANG=C.UTF-8 推奨）

require_relative '../spec/support/kanbun_fixtures'
require_relative '../lib/kanbun/kakikudashi'

$checks = 0
$failures = []

def check(label, expected, actual)
  $checks += 1
  return if expected == actual

  $failures << "FAIL #{label}\n    expected: #{expected.inspect}\n    actual:   #{actual.inspect}"
end

def check_raises(label, klass)
  $checks += 1
  yield
  $failures << "FAIL #{label}: #{klass} が送出されなかった"
rescue klass
  nil
rescue StandardError => e
  $failures << "FAIL #{label}: #{klass} のはずが #{e.class}: #{e.message}"
end

A = Kanbun::Aozora
K = Kanbun::Kakikudashi

KanbunFixtures::CASES.each do |c|
  check("#{c[:name]} / hakubun", c[:hakubun], A.hakubun(c[:text]))
  check("#{c[:name]} / kaki", c[:kaki], K.convert(c[:text], yomi: false))
  check("#{c[:name]} / kaki_yomi", c[:kaki_yomi], K.convert(c[:text], yomi: true))
  check("#{c[:name]} / kaki_hira", c[:kaki_hira], K.convert(c[:text], yomi: false, hiragana: true))
end

# --- 白雲期 ---
lines = KanbunFixtures.hakuunki_lines
check('hakuunki / 行数', KanbunFixtures::HAKUUNKI_KAKI.size, lines.size)
check('hakuunki / 白文が原文と一致（句読点なし）', KanbunFixtures::HAKUUNKI_ORIGINAL,
      lines.map { |l| A.hakubun(l, punctuation: false) }.join)
lines.zip(KanbunFixtures::HAKUUNKI_KAKI).each_with_index do |(text, kaki), i|
  check("hakuunki / #{i + 1} 対句 書き下し", kaki, K.convert(text, yomi: false))
end

KanbunFixtures::UNRESOLVED.each do |name, text|
  check_raises("unresolved #{name}", Kanbun::Reorder::Error) do
    Kanbun::Reorder.reorder(A.parse(text))
  end
end

# --- 字句解析の構造チェック（aozora_spec.rb と同内容） ---
u = A.parse('未《いま》ダ〈ざ〉ル［＃レ］').first
check('saidoku yomi', 'いま', u.yomi.text)
check('saidoku okuri', 'ダ', u.okuri)
check('saidoku text', 'ざ', u.saidoku.text)
check('saidoku hidden', true, u.saidoku.hidden?)
check('saidoku_okuri', 'ル', u.saidoku_okuri)
check('saidoku kunten', 'レ', u.kunten)

u = A.parse('不〈〉〈ズ〉［＃乙］').first
check('first reading empty', '', u.yomi.text)
check('second reading', 'ズ', u.saidoku.text)
check('otsu', '乙', u.kunten)

u = A.parse('盍《なん》［＃（ゾ）］〈ザ〉［＃（ル）］［＃レ］').first
check('bracket okuri', 'ゾ', u.okuri)
check('bracket saidoku_okuri', 'ル', u.saidoku_okuri)

check('ichi-re', '一レ', A.parse('有ルガ［＃一レ］').first.kunten)
check('ichi-re order_mark', '一', A.parse('有ルガ［＃一レ］').first.order_mark)
check('kj-re', '甲レ', A.parse('乱サ［＃甲レ］').first.kunten)
check('okiji', ['', true], (r = A.parse('矣〈〉').first.yomi; [r.text, r.hidden?]))
check('punctuation', %w[王 、], A.parse('王、').map(&:kanji))
check('tate U+2010', true, A.parse("如‐何").first.tate?)
check('tate ASCII', true, A.parse('如-何').first.tate?)
check('variation selector', "葛\u{E0100}", A.parse("葛\u{E0100}ヲ").first.kanji)
check('extension B kanji', '𠮟', A.parse('𠮟ル').first.kanji)
check('newline ignored', %w[王 、], A.parse("王\n、").map(&:kanji))
check('tate reorder', %w[如 何], Kanbun::Reorder.reorder(A.parse("如‐何")).map(&:kanji))

check_raises('parse error', A::ParseError) { A.parse('王ABC') }
begin
  A.parse('王ABC')
rescue A::ParseError => e
  check('parse error position', true, e.message.include?('2 文字目'))
end

puts "#{$checks} checks, #{$failures.size} failures"
$failures.each { |f| puts f }
exit($failures.empty? ? 0 : 1)
