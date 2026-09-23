# app/services/kanbun_parser_service.rb
#
# 役割: 漢文白文 → 訓点付き漢文・書き下し文を生成する
# 実装: Raccパーサー（フェーズ1: 否定・禁止句法実装済み）をラップする
# 現在: パイプライン接続確認のためパススルー実装
#
class KanbunParserService
  def self.call(hakubun)
    # TODO: Raccパーサーとの接続
    # 訓点付与・書き下し文生成はフェーズ2以降で完成させる
    {
      kunten:      hakubun,
      kakikudashi: hakubun
    }
  end
end
