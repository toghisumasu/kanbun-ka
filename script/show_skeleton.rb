# frozen_string_literal: true

# 骨格（SkeletonBuilder の出力）と白文を並べて見る診断用。LLM の誤りが骨格由来かを切り分ける。
#
#   bin/rails runner script/show_skeleton.rb              … 既定の 8 文
#   bin/rails runner script/show_skeleton.rb "兄は海で魚を釣る" …  指定した文

DEFAULT = %w[
  これは楽しくないか 私は何も知らない ただ人だけが言葉を話す 知らない者はいない
  飲まない人はいない 兄は海で魚を釣る 友と酒を飲んで語る 美しい花が咲いている
].freeze

(ARGV.empty? ? DEFAULT : ARGV).each do |text|
  r = KanbunTranslatorService.call(text)
  puts "原文: #{text}"
  puts "  骨格: #{r.skeleton.inspect}"
  puts "  白文: #{r.hakubun}"
end
