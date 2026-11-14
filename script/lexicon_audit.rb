# frozen_string_literal: true

# Yomi の読みの表で、「読みの中に、ほかの項目や実字の漢字が重複して入る」ものを列挙する（修正はしない）。
#
#   bin/rails runner script/lexicon_audit.rb
#
# 副詞表（ADVS）は、表層形のあとに送り仮名を足して書き下しにする。送り仮名に漢字が入ると、
# その漢字が表層形や別の語と二重に出る（例：何独 => 'ぞ独り' は 何独ぞ独り になり 独 が重複する）。
#   A. 送り仮名に漢字が入る
#   B. その漢字が、自分の表層形に含まれる（自己重複）
#   C. その漢字が、別の項目（副詞・動詞・形容詞・名詞など辞書にある語）の字でもある
# 副詞表以外の読みの表（ADJS の語幹・SAIDOKU_SECOND・VERBS の活用語尾）にも、同じ検査をかける。
KanbunParserService # lib/kanbun の読み込み

Y = Kanbun::Yomi
HAN = /\p{Han}/

def kanji_in(str) = str.to_s.scan(HAN)

def other_entries(char, self_surface)
  Kanbun::Lexicon::TABLE.keys.select { |k| k != self_surface && k.include?(char) }
end

findings = []
audit = lambda do |table, surface, reading|
  chars = kanji_in(reading)
  next if chars.empty?

  chars.uniq.each do |c|
    kinds = ["A 送り仮名に漢字 #{c}"]
    kinds << "B 自分の表層形 #{surface} にも #{c}" if surface.include?(c)
    others = other_entries(c, surface)
    kinds << "C ほかの語にも #{c}: #{others.first(6).join(' ')}#{others.size > 6 ? ' …' : ''}" unless others.empty?
    findings << [table, surface, reading, kinds]
  end
end

Y::ADVS.each { |s, r| audit.call("ADVS", s, r) }
Y::ADJS.each { |s, (_type, stem)| audit.call("ADJS", s, stem) }
Y::SAIDOKU_SECOND.each { |s, (forms, _d)| audit.call("SAIDOKU_SECOND", s, forms.join) }
Y::VERBS.each { |s, v| audit.call("VERBS", s, v[:forms].join + v[:obj].to_s + v[:comp].to_s) }

# 全体の読み（ADV_WHOLE）は、表層形の字を順に 1 回ずつ含むこと（余分・重複の漢字がない）
wholes = Y::ADV_WHOLE.reject { |s, r| r.scan(HAN).join == s }

puts "検査対象: 副詞表 #{Y::ADVS.size} 項目／ADJS #{Y::ADJS.size}／SAIDOKU_SECOND #{Y::SAIDOKU_SECOND.size}／VERBS #{Y::VERBS.size}"
puts "全体の読み ADV_WHOLE #{Y::ADV_WHOLE.size} 項目: #{wholes.empty? ? '表層形と矛盾なし' : '矛盾 ' + wholes.inspect}"
if findings.empty?
  puts "重複の疑い: なし"
else
  puts "重複の疑い: #{findings.size} 件"
  findings.each do |table, surface, reading, kinds|
    puts "  [#{table}] #{surface} => #{reading.inspect}"
    kinds.each { |k| puts "      #{k}" }
  end
end
