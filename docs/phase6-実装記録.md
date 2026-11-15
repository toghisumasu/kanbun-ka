# Phase 6a 実装記録（確認済み印の仕組み）

ブランチ: `phase6a-verified`（`phase5b` から分岐。`main` には触れない）。
この段は仕組みの導入だけ。辞書の中身・文法・プロンプトは変えない。確認済み一覧は空から始める。

## P0：読むだけ（事実のみ。lib/kanbun/yomi.rb は phase5b 末尾の状態）

分岐前の `git status`：未追跡 `.DS_Store`、`docs/kanbun ka issues draft.md`、`docs/kanshi.tsv`、`docs/next thread prompt kanbun ka v1.md` のみ（変更なし）。
`git branch --show-current`：`phase5b`。

### (a) Yomi が辞書を引く箇所（lib/kanbun/yomi.rb）

| 表 | キー | 引く箇所（行） | 何を取るか |
|---|---|---|---|
| VERBS | 表層形 | 209 `noun_like?`（`key?`）| 述語が動詞か（目的語の名詞扱い判定） |
| VERBS | head.surface | 227 `head_cases`（`VERBS[..]`）| obj／comp／cases（助詞） |
| VERBS | surf | 351 `render_content`（`key?`）| 動詞として読むか |
| VERBS | surf | 373 `conjugate_verb`（`fetch`）| forms（活用 5 形） |
| ADJS | head.surface | 231 `head_cases`（`key?`）| 助詞 より |
| ADJS | surf | 349 `render_content`（`key?`）| 形容詞として読むか |
| ADJS | surf | 401 `conjugate_adj`（`fetch`）| 型と語幹 |
| ADV_WHOLE | surf | 355-356 `render_content` | 全体の読み |
| ADVS | surf | 357-358 `render_content` | 送り仮名 |
| SAIDOKU_SECOND | item.surface | 415 `saidoku`（`fetch`、2 度目のみ）| 2 度目の読みと demand |
| Lexicon::TABLE（語種） | 表層形 | 209・211 `noun_like?`、338-339 `noun?`、346・353 `render_content`、463 `add_topic!` | 語種（NOUN／VERB…）による分岐 |
| Lexicon::SAIDOKU（1 度目の読み） | 字 | 409-412 `saidoku`（`leaf.saidoku`）| 1 度目の読みと送り仮名 |

`render_content` の分岐順は ADJS → VERBS → NOUN → ADV_WHOLE → ADVS → MissingEntry。

表を引かず、`render` の `case`（255-283）や各メソッドの中に読みが直書きされているもの：
不・弗・可・而・矣・焉・也・乎・哉・邪・於・于・所・者・則・若・非・無・莫・勿・使・令・被・自・従・与・其、
dneg（得・可）、ukemi_i（為）、hikyo（如）、compare_verb／compare_neg（如・若・莫・不）、ruika_adv（徒・唯・独、445 行）、ruika_neg。
これらは表ではないので、この段の「項目」には含めない。

### (b) 既定値で読みを補う箇所

| 種類 | 位置 | 内容 |
|---|---|---|
| 助詞の既定 | 44 `v(..., obj: 'を', comp: 'に')` | 動詞が obj／comp を明示しないとき 「を」「に」。229 の `['の', verb[:obj]]` も obj に依存 |
| 活用形の既定 | 292・310・322・328・383・390 `dem[:form] \|\| :shushi`、366 `form_for`、373・403・417 `FORMS.index(form) \|\| 2`、317・323・329・394 `fetch(form, 'ず')` 等 | 直前の語が形を要求しないとき終止形 |
| 与・自・従の落ち許容 | yomi.rb 278-279（読みは空文字）＋ fukubun.rb `PARTICLE_ONLY` | 項目が出力に残らなくても検査を通す |
| 名詞の表層形＋助詞 | 354 `render_content`、287-288 `it_part`、463-467 `add_topic!` | 名詞は表を引かず、表層形に助詞（なければ空）を付ける |

### (c) exact の式と、載る項目

`app/services/kanbun_parser_service.rb#kakikudashi`：
`problems = Fukubun.check(tree, result.text, parts: result.parts) + result.ambiguities`。
`problems` が空なら `[result.text, true, []]`、そうでなければ `[interim(aozora), false, problems]`。`MissingEntry` は `[interim, false, [message]]`。

`Yomi::Result`：`text`・`ambiguities`・`parts`（`Piece(leaf, second, text)`）。
`KanbunParserService.call` の戻り：`kunten`・`kakikudashi`・`kakikudashi_exact`・`kakikudashi_reasons`・`kunten_aozora`・`status`・`error`。
`KanbunTranslatorService::Result`：…`kakikudashi_exact`・`kakikudashi_reasons`（130-131 行で `kunten_result` から転記）。
`script/kanbun_repl.rb`：25-26 行で exact と reasons を表示。

### 前提の確認
`analyze` は項目（Item）を 1 つずつ描画するので、描画の中で「どの表のどのキーを引いたか」を記録して Result に載せられる。前提は崩れていない。

### 着手前の基準値（実測）
- RSpec：740 examples, 0 failures, 25 pending
- Racc conflict（`grep -ciE "conflict|useless|never reduced" lib/kanbun/kanbun_parser.output`）：0
- `exact_wide_report`：文数 360、exact 256／復文検査の違反 0／その他 104
- `exact_report`（bench の期待白文 50 行）：EXACT 41／それ以外 9
- bench（Ollama 実行）は、コード変更のない段（S1〜S3）の後ではなく、S4 以降の完了確認でまとめて実行する。

### 設計メモ（P0 を踏まえた具体化）
- 「助詞の既定」は、動詞が obj／comp を明示していないとき。いまは `v()` が既定値を埋めるので、
  表の中身は変えず、`v()` が「明示されたか」を `defaults:` として持つ形にする（辞書の読みは変えない）。
- 「活用形の既定」は、動詞・形容詞の描画時に `dem[:form]` が無かったときだけ記録する。
- 名詞は対象外：表を持たず表層形をそのまま出すため、確認する対象となる「読み」が存在しない。
- 与・自・従は、この段では記録しない（空文字の読みで「落ちる」のが仕様で、落ちた事実を既定値と区別できない）。残課題。
