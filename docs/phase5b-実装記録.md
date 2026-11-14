# Phase 5b 実装記録

ブランチ `phase5b`（`phase5a` から）。目的：`kakikudashi_exact: true` を「Yomi の自己申告」ではなく「機械検査の結果」にする。
導入前の基準：ベンチ期待白文 50 句のうち exact:true は 41 件（`tmp/exact_before.tsv`、`script/exact_report.rb` で再現）。

## S1 曖昧な受身（パーサーが木に ambiguous を付ける）

- 実装：`Kanbun::Tree::Ambiguous`（Leaf／Seq／Ret に `ambiguous`）、`Tree.ambiguities`、`Tree.clear_ambiguous!`。Racc の規則が付ける：`VERB PREP NOUN`（殺於敵）、`為A V`（所なし。為敵殺・彼為敵殺）。`Yomi` は `Tree.ambiguities` が空のときだけ exact とする（以前は Yomi が木を走査して判定していた）。
- 計画から外れた点：
  1. **見V は exact:true に変更**（指示どおり。phase5a では ambiguous としていた。「見V は Vを見る かもしれない」という曖昧さは残るが、受身の確定形として扱う）。
  2. `Lexicon::LOCATIVE_VERBS`（入 行 去 帰 還 登 在 有 及 成）を新設。於A が行き先・場所で受身にならない動詞は、`VERB PREP NOUN` でも ambiguous にしない（入於深林 などを不必要に落とさないため）。
  3. `被V於A` の内側の `V於A` は受身が確定するので、`clear_ambiguous!` で外す。
  4. `学於人` は保守的に ambiguous のまま（学が他動詞で LOCATIVE_VERBS にないため）。
- 検証：spec 先行（赤 16 件→緑）。RSpec 670 件、conflict 0。exact は 41/50 のまま（phase5a でも 殺於敵 系は false だったため変化なし）。

## S2 復文検査モジュール（Service には未接続）

- 実装：`lib/kanbun/fukubun.rb`（`Kanbun::Fukubun.check(tree, kakikudashi)` → 理由の配列）。`Lexicon` に `OKIJI_TOKENS`・`OKIJI`・`CONTENT_TOKENS` を追加し、置き字・実字の定義はここだけに置いた。
- 検査：実字の欠落／重複（字ごとの出現回数）、読み順（`Kunten.annotate` → `Reorder.reorder` の結果と、書き下しの実字の並びを比較。回数が合っていて順序だけ違うときに報告）、再読文字（1 度目の漢字のあとに `Lexicon::SAIDOKU` の 2 度目の読みが続く）。理由は「字の欠落: 学」「字の重複: 読」「読み順の不一致: 期待 … / 実際 …」「再読文字が2度出ていない: 未」。
- 計画から外れた点：
  1. `見V` の 見 は受身の助動詞（殺さる）として読み、漢字が書き下しに出ない。実字に数えない例外を `FUNCTION_ROLES = [:ukemi_mi]` に置いた（検査側の表。見V が exact:true なので必要）。
  2. 項目 4（重複）は、項目 1 と同じ「字ごとの出現回数」の比較の片側（多い方）として実装した。
  3. 置き字の「除外」は、置き字が `CONTENT_TOKENS` に入らないことで実現している。置き字が書き下しに**出ていること**は検査しない（指示の 4 項目外。累加の「、而も」のように読む而もあるため）。phase5a の `Yomi` にあった置き字検査は S3 で Fukubun に置き換える。
- 検証：spec 先行（赤＝モジュールなし）。正例 28 文（既存の固定文）が違反なし、欠落・重複・字順入れ替え・再読文字の欠けを検出。RSpec 709 件、conflict 0。
