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
