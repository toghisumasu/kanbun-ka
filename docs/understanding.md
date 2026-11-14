# 理解の記録（understanding）

## 2026-11-14 Phase 5a M1：不得不・不可不

- したこと：`不得不`・`不可不` を 3 字 1 トークン（DNEG_TOKU / DNEG_KA）にし、二重否定②として専用規則を追加した。
- 直した誤り：以前は `不得不知` が `不得 | 不知`（seq_neg_clause）として偶然通り、返り点 `不[レ]得不[レ]知`・読み順「得不知不」と、エラーなしで誤った結果を出していた。
- 検証：kunten_spec に 5 句を追加（先に赤を確認）。RSpec 400 件通過、Racc conflict 0（`lib/kanbun/kanbun_parser.output`）。
- 明文化した前提：
  - `.y` の正本は `script/kanbun_parser.y`。`bundle exec racc -v script/kanbun_parser.y -o lib/kanbun/kanbun_parser.tab.rb` で再生成する。`.output` は lib/kanbun 側に出る（script 側の `.output` は古い残骸で、gitignore 対象）。
  - 「不得」「不可」を 2 語で続けて読ませる文（不得 | 不行 のような読み）は、3 字トークンが最長一致で優先するため通らなくなる。
- 未了：書き下し「知らざるを得ず」「学ばざるべからず」は M6（読み辞書・活用）で出す。
