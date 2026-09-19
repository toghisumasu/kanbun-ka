# kanbun-ka フェーズ1 作業手順書

2026-09-19

## 目標と完了条件

Raccを使って否定句法（不・弗・非・無・莫）と禁止句法（莫・勿・無）をLRパーサーで処理し、漢文白文に返り点の情報を付与できる状態にする。

**完了条件**:

- `script/kanbun_parser.y` が構文エラーなくRacc生成できる
- 全テストケース（下表）がパスする
- 生成した`kanbun_parser.tab.rb`をServiceクラスから呼び出せる

## 事前準備

```bash
# kanbun-kaディレクトリで
grep racc Gemfile   # 確認済み：追加済み
bundle install      # 確認済み：インストール済み

# 作業場所
cd /Volumes/externalHDD/projects/kanbun-ka/script/
ls   # kanbun_parser.y が存在することを確認
```

`kanbun_parser.y` は `script/` に配置済み（vim で作成）。現在の状態：否定（不）のみ実装、「不読書」でエラー（VERB+VERB 未対応）。

## ステップ1: 文法ファイル拡張

`script/kanbun_parser.y` を以下の内容に書き換える。否定・禁止の全句法と多義字対応を含む。

```ruby
class KanbunParser

# トークン定義
token NEG_BU NEG_FU NEG_HI NEG_MU NEG_BAKU
      PROHIBIT_NAKA PROHIBIT_MOTSU
      VERB NOUN

rule
  sentence
    : clause { result = val[0] }

  clause
    : neg_clause      { result = val[0] }
    | prohibit_clause { result = val[0] }
    | verb_phrase     { result = val[0] }

  # 否定句法
  neg_clause
    : NEG_BU  verb_phrase { result = "不#{val[1]}" }   # 不〜ず
    | NEG_FU  verb_phrase { result = "弗#{val[1]}" }   # 弗〜ず
    | NEG_HI  verb_phrase { result = "非#{val[1]}" }   # 非〜にあらず
    | NEG_MU  verb_phrase { result = "無#{val[1]}" }   # 無〜なし
    | NEG_BAKU verb_phrase { result = "莫#{val[1]}" }  # 莫〜なし

  # 禁止句法
  prohibit_clause
    : NEG_BAKU verb_phrase { result = "莫#{val[1]}" }      # 莫〜なかれ
    | PROHIBIT_NAKA verb_phrase { result = "勿#{val[1]}" } # 勿〜なかれ
    | NEG_MU   verb_phrase { result = "無#{val[1]}" }      # 無〜なかれ

  # 動詞句（多義字：VERB+VERB も許容）
  verb_phrase
    : VERB            { result = val[0] }
    | VERB NOUN       { result = "#{val[0]}#{val[1]}" }
    | VERB VERB       { result = "#{val[0]}#{val[1]}" }
    | NOUN            { result = val[0] }

end

---- header
require 'strscan'

---- inner

VERBS = %w[学 読 書 見 聞 知 行 来 食 飲 思 言 得 去 入 出 為]
NOUNS = %w[人 君 臣 子 民 文 道 国 師 天 地 王 士 物 事]

def parse(str)
  @tokens = tokenize(str)
  @pos = 0
  do_parse
end

def next_token
  @tokens[@pos].tap { @pos += 1 }
end

def tokenize(str)
  tokens = []
  scanner = StringScanner.new(str)
  until scanner.eos?
    case
    when scanner.scan(/不/) then tokens << [:NEG_BU,        '不']
    when scanner.scan(/弗/) then tokens << [:NEG_FU,        '弗']
    when scanner.scan(/非/) then tokens << [:NEG_HI,        '非']
    when scanner.scan(/無/) then tokens << [:NEG_MU,        '無']
    when scanner.scan(/莫/) then tokens << [:NEG_BAKU,      '莫']
    when scanner.scan(/勿/) then tokens << [:PROHIBIT_NAKA, '勿']
    when scanner.scan(Regexp.new("[#{VERBS.join}]")) then tokens << [:VERB, scanner.matched]
    when scanner.scan(Regexp.new("[#{NOUNS.join}]")) then tokens << [:NOUN, scanner.matched]
    else scanner.getch
    end
  end
  tokens << [false, nil]
  tokens
end

---- footer

if __FILE__ == $0
  parser = KanbunParser.new
  tests = %w[不学 不読書 弗能 非吾願 無足 莫笑 勿施 無敢食]
  tests.each do |input|
    result = parser.parse(input)
    puts "#{input} => #{result}"
  rescue => e
    puts "#{input} => エラー: #{e.message}"
  end
end
```

## ステップ2: パーサー生成と動作確認

```bash
cd /Volumes/externalHDD/projects/kanbun-ka/script/

# .y → .tab.rb 生成
bundle exec racc kanbun_parser.y

# 生成ファイル確認
ls -la kanbun_parser.tab.rb

# テスト実行
ruby kanbun_parser.tab.rb
```

**期待する出力**:

```
不学 => 不学
不読書 => 不読書
弗能 => 弗能
非吾願 => 非願   # 吾はNOUN・VERB辞書に未登録のためスキップ
無足 => 無足
莫笑 => 莫笑
勿施 => 勿施
無敢食 => エラー（敢が辞書未登録）
```

エラーが出た字は都度 VERBS/NOUNS リストに追加する。

## ステップ3: Railsへの組み込み

パーサー単体の動作確認が取れたら `lib/` に移してServiceから呼ぶ。

```bash
# lib/ に移動
mkdir -p lib/kanbun
cp script/kanbun_parser.y   lib/kanbun/
cp script/kanbun_parser.tab.rb lib/kanbun/
```

```ruby
# app/services/kanbun_parser_service.rb
require_relative '../../lib/kanbun/kanbun_parser.tab'

class KanbunParserService
  def initialize
    @parser = KanbunParser.new
  end

  def parse(kanbun_text)
    @parser.parse(kanbun_text)
  rescue => e
    { error: e.message, input: kanbun_text }
  end
end
```

Railsコンソールで動作確認：

```bash
bundle exec rails console
> svc = KanbunParserService.new
> svc.parse("不学")
=> "不学"
```

## テストケース一覧

| 入力 | 期待出力 | 句法 | 備考 |
| --- | --- | --- | --- |
| 不学 | 不学 | 否定・不 | 動詞単体 |
| 不読書 | 不読書 | 否定・不 | 動詞＋名詞(書) |
| 不知道 | 不知道 | 否定・不 | 動詞＋名詞 |
| 弗能 | 弗能 | 否定・弗 | |
| 無足 | 無足 | 否定・無 | |
| 莫笑 | 莫笑 | 禁止・莫 | |
| 勿施 | 勿施 | 禁止・勿 | |
| 見人 | 見人 | 動詞句 | 否定なし |
| 知道 | 知道 | 動詞句 | 否定なし |

## 次フェーズへの移行条件

フェーズ1完了後、以下を確認してからフェーズ2（比較・選択・二重否定）に進む。

- [ ] 全テストケースがパス
- [ ] Railsコンソールから `KanbunParserService` 経由で呼び出し成功
- [ ] VERBS/NOUNSリストが主要な漢文用字（50字程度）をカバー
- [ ] `script/kanbun_parser.y` を `lib/kanbun/` に移動済み
- [ ] GitコミットしてGitHubにpush済み
