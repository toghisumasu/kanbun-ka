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

