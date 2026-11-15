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

## S2〜S5 の実装（各段 spec 先行・赤を確認）

| 段 | コミット | 内容 | 赤の確認 |
|---|---|---|---|
| S1 | f8b312a | 上の P0 | － |
| S2 | 1eb62f9 | `Yomi::Result#used_entries`。項目 ID「表名:キー」（VERBS／ADJS／ADVS／ADV_WHOLE／SAIDOKU／SAIDOKU_SECOND）、既定値は「DEFAULT:particle:字」「DEFAULT:form:字」。`Yomi.collecting`／`note`。`v()` が obj／comp を明示したかを `defaults:` に持つ | 13 例が NoMethodError（`used_entries`）で失敗 |
| S3 | d958ea3 | `lib/kanbun/verified_entries.yml`（空 `{}`）と `Kanbun::VerifiedEntries`（読み込み・`verified?`・`unverified`。DEFAULT・知らない表・辞書にないキーは拒否） | LoadError（モジュールなし）。※例ごとの赤ではなく読み込み失敗 |
| S4 | a7fc2ff | `KanbunParserService`：`kakikudashi_tree_ok`／`kakikudashi_verified`／`kakikudashi_unverified`／`kakikudashi_exact`、理由。Translator::Result と REPL に通す | 10 例が失敗（キーなし） |
| S5 | 47026fe | `exact_report.rb`（集計は標準エラー）・`exact_wide_report.rb` に tree_ok／verified／exact と未確認項目ランキング上位30 | － |

### 逸脱・判断（指示と違う点、決めた点）
1. **未確認だけのとき、書き下しは暫定の漢字列に戻さず Yomi の読みのまま返す**（`exact:false`＋理由）。指示は「exact:false（暫定）にして理由を出す」で、書き下し本体をどうするかは書かれていない。一覧が空のうちは全文が暫定の漢字列になり、読みが使えなくなるため。tree_ok が false のとき（従来の暫定条件）は従来どおり暫定の漢字列。**要確認**：未確認のときも暫定の漢字列に戻す方がよいか。
2. `v()` の引数の既定を `obj: nil, comp: nil` に変えた（読みは同じ。明示の有無を記録するため）。辞書の内容は変えていない。363 文の書き下しが旧コードと一致することを確認した（下記）。
3. 助詞の既定は「動詞が obj／comp を明示せず、かつその助詞を名詞に付けたとき」だけ記録する。二名詞の 1 つ目の「の」は固定値なので対象外。
4. **既存 spec の変更**：`kanbun_parser_service_spec.rb` の 4 例で `exact:true` を `tree_ok:true`（5b の意味）に変え、理由の検査は未確認／既定値の行を除いて行う。一覧が空の間、`exact:true` は辞書項目を使わない文だけになるため。
5. 名詞は対象外：表を持たず、表層形に助詞を付けるだけで、確認する「読み」がない。語種（Lexicon の NOUN）の判定は確認対象にしない。
6. 与・自・従は記録しない（読みが空文字で「落ちる」のが仕様で、落ちた事実と既定値を区別できない）。残課題。
7. `render` の `case` に直書きされた機能語（不・可・而・也・非・無 など）、再読以外の比較・累加・受身の読みは表ではないので項目にならない（＝確認印の対象外）。**exact:true が残る原因になっている**（下記）。

## S6 完了の確認（実測）

### 数値
| 項目 | 実測 | 備考 |
|---|---|---|
| RSpec | 774 examples, 0 failures, 25 pending | pending は 25 のまま |
| Racc 衝突（`grep -ciE "conflict\|useless\|never reduced" lib/kanbun/kanbun_parser.output`） | 0 | 文法は変えていない |
| bench（`translate_bench.rb`、Ollama） | 白文率 50/50・解析率 49/50・**一致率 47/50**・完全成功 47/50 | S9 直後（phase5b 末尾）と同じ 47。47 は指示の 48 未満だが、**この段で変わっていない**（S9 から既知） |
| bench の期待白文 50 行（`exact_report.rb`） | 解析 47 / tree_ok **41** / verified 1 / exact 1 | tree_ok 41 は従来の exact 41 と一致。書き下しも 50 行すべて同一 |
| 363 文（`exact_wide_report.rb`。bench の別表記＋spec に出る漢字の文） | 解析 306 / tree_ok **257** / verified 28 / exact 28 | 360→363 は、この段で足した spec の文字列が 3 つ入ったため |
| 同じ 363 文を phase5b の旧コードに通した exact | **257** | 363 文すべてで tree_ok と旧 exact が一致し、書き下しも同一（`diff` 空） |

「256（従来の exact）」は 360 文のときの値。同じ 363 文で旧 257 ＝ tree_ok 257。

**指示の見込みと違う点**：verified と exact は 0 ではなく **28**（bench 期待白文では 1：無水）。一覧が空でも、使った辞書項目が 0 の文（名詞と機能語の直書きだけ）は「全部確認済み」になるため。内訳（363 文中）：
無水・王・我・漢文・深林・老子・兵法・二月花・林檎・臣下・無患・無人・君子也・人生如夢・人如山・人若山・人莫若友・人不如友・地不若人・地不若深林・彼非君子・彼非君子也・非徒無益・非唯無益・不独無益・無非君子・**無非王土**・**孔子聖人**・（孔子君子 は上の 28 には含まれない：363 文に入っていない）。

### 前回調査「黙って誤る」22項目の再実行（`KanbunParserService.call`）

**exact:true のまま残るもの（先に）**

| # | 白文 | 書き下し | tree_ok | verified | exact | 残る理由 |
|---|---|---|---|---|---|---|
| 1 | 無非王土 | 王は土に非ざる無し | true | true | **true** | 使う辞書項目が 0（名詞＋直書きの無・非）。構造の誤りで、確認印では捉えられない |
| 4 | 孔子聖人 | 孔子聖人 | true | true | **true** | 名詞のみ。名詞述語の「なり」が付かない誤りは検査にも出ない |
| 4 | 孔子君子 | 孔子君子 | true | true | **true** | 同上 |

**exact:false だが、辞書とは別の原因の誤りが残っているもの**（未確認の項目があるので止まっているだけ。その項目を確認済みにすると、誤りのまま exact:true に戻る）

| # | 白文 | 誤りの種類 | いま exact:false の理由 |
|---|---|---|---|
| 2 | 無人不飲 | 構造 | 未確認: VERBS:飲 |
| 3 | 学与／君学与 | 与の脱落（検査の例外） | 未確認: VERBS:学 |
| 5 | 陽貨帰孔子豚 | 構造（二重目的語） | 未確認: VERBS:帰 |
| 6 | 王命臣行 | 構造 | 既定値 助詞（命）／未確認 VERBS:命・VERBS:行 |
| 22 | 氷莫如水冷 | 構造 | 未確認: ADJS:冷 |

**辞書由来（exact:false。予想どおり）**：7 及・8 随・9 施・10 対・11 照・12 散/満・13 重・14 欹・15 起・16 得・17 陥・18 為・19 賢・20 大・21 尽/甚。全件 tree_ok:true／verified:false／exact:false。

全 26 行の実測（reasons は項目 ID つき）：

| # | 白文 | status | 書き下し | tree_ok | verified | exact | reasons |
|---|---|---|---|---|---|---|---|
| 1 | 無非王土 | parsed | 王は土に非ざる無し | true | true | true |  |
| 2 | 無人不飲 | parsed | 人無く飲まず | true | false | false | 未確認の辞書項目: VERBS:飲 |
| 3 | 学与 | parsed | 学び | true | false | false | 未確認の辞書項目: VERBS:学 |
| 3 | 君学与 | parsed | 君学び | true | false | false | 未確認の辞書項目: VERBS:学 |
| 4 | 孔子聖人 | parsed | 孔子聖人 | true | true | true |  |
| 4 | 孔子君子 | parsed | 孔子君子 | true | true | true |  |
| 5 | 陽貨帰孔子豚 | parsed | 陽貨孔子の豚に帰る | true | false | false | 未確認の辞書項目: VERBS:帰 |
| 6 | 王命臣行 | parsed | 王臣を命じ行く | true | false | false | 既定値: 助詞（命）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:行 / 未確認の辞書項目: VERBS:命 |
| 7 | 行楽須及春 | parsed | 行楽須らく春を及ぶべし | true | false | false | 既定値: 助詞（及）：助詞を辞書が明示していない / 未確認の辞書項目: SAIDOKU_SECOND:須 / 未確認の辞書項目: VERBS:及 / 未確認の辞書項目: SAIDOKU:須 |
| 8 | 随風潜入夜 | parsed | 風を随ひ潜かに夜に入る | true | false | false | 既定値: 助詞（随）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:入 / 未確認の辞書項目: ADVS:潜 / 未確認の辞書項目: VERBS:随 |
| 9 | 勿施人 | parsed | 人を施すこと勿かれ | true | false | false | 既定値: 助詞（施）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:施 |
| 10 | 人対客 | parsed | 人客を対ふ | true | false | false | 既定値: 助詞（対）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:対 |
| 11 | 復照青苔上 | parsed | 復た青苔の上を照る | true | false | false | 既定値: 助詞（照）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:照 / 未確認の辞書項目: ADVS:復 |
| 12 | 散入春風満洛城 | parsed | 散春の風に入り洛城を満つ | true | false | false | 既定値: 助詞（満）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:満 / 未確認の辞書項目: VERBS:入 / 未確認の辞書項目: ADVS:散 |
| 13 | 花重錦官城 | parsed | 花錦官城を重ぬ | true | false | false | 既定値: 助詞（重）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:重 |
| 14 | 遺愛寺鐘欹枕聴 | parsed | 遺愛寺鐘枕を欹ち聴く | true | false | false | 既定値: 助詞（欹）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:聴 / 未確認の辞書項目: VERBS:欹 |
| 15 | 何人不起故園情 | parsed | 何人故園の情を起きず | true | false | false | 既定値: 助詞（起）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:起 |
| 16 | 彼得名 | parsed | 彼は名を得 | true | false | false | 既定値: 助詞（得）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:得 |
| 17 | 彼陥敵 | parsed | 彼は敵を陥る | true | false | false | 既定値: 助詞（陥）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:陥 |
| 18 | 彼為王 | parsed | 彼は王を為す | true | false | false | 既定値: 助詞（為）：助詞を辞書が明示していない / 未確認の辞書項目: VERBS:為 |
| 19 | 彼賢友 | parsed | 彼は友賢し | true | false | false | 未確認の辞書項目: ADJS:賢 |
| 20 | 不亦大乎 | parsed | 亦た大ほからずや | true | false | false | 未確認の辞書項目: ADJS:大 / 未確認の辞書項目: ADVS:亦 |
| 20 | 不大 | parsed | 大ほからず | true | false | false | 未確認の辞書項目: ADJS:大 |
| 21 | 不尽知 | parsed | 尽く知らず | true | false | false | 未確認の辞書項目: VERBS:知 / 未確認の辞書項目: ADVS:尽 |
| 21 | 不甚美 | parsed | 甚だ美しからず | true | false | false | 未確認の辞書項目: ADJS:美 / 未確認の辞書項目: ADVS:甚 |
| 22 | 氷莫如水冷 | parsed | 氷は水冷たくに如くは莫し | true | false | false | 未確認の辞書項目: ADJS:冷 |

### 確認できなかったもの
- 実際に「確認済み」にした項目での動作（本番の一覧は空）。ダミー一覧での spec のみ（verified_entries_spec・kanbun_parser_service_verified_spec）。
- `DEFAULT:form` は、363 文では 1 件も出ない（直接 `conjugate_verb` に空の demand を渡す spec でのみ確認）。実運用で発火するかは不明。
- 機能語の直書き読み（不・非・無・也・乎・哉…）が正しいかは、この仕組みでは見えない。
- bench は LLM（Ollama）の出力に依存する。今回の値は 1 回の実行。

### 想定外の発見
1. 一覧が空でも exact:true が 28 文（bench 期待白文では 1 文）残る。名詞と機能語の直書きだけの文は検査対象外。無非王土・孔子聖人 が含まれる。
2. 構造の誤り・与の脱落は、辞書項目が未確認である間だけ偶然 exact:false になっている。項目を 1 つずつ確認済みにすると、これらが exact:true に戻る。確認の順を決めるときに、この種の文を先に別の手当てが要る（次の段の対象）。
3. 動詞の大半が `obj` を明示していないため、目的語を取る文は DEFAULT:particle で必ず exact:false になる（363 文中 105 文）。これらを exact にするには、辞書に obj の明示データを足す必要がある（設計どおりだが、確認作業の量に効く）。
4. 未確認項目の使用頻度の上位は VERBS:学（41）・知（22）・読（20）・DEFAULT:particle:読（17）・殺（14）・行（14）・飲（13）。
