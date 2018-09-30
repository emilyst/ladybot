# frozen_string_literal: true

shared_context 'plugin context', shared_context: :metadata do
  let(:nick) { 'scrooge' }
  let(:channel) { '#duckberg' }
  let(:bot) do
      Cinch::Bot.new do
        configure do |c|
          c.server          = 'localhost'
          c.nick            = 'ladytest'
          c.user            = 'ladytest'
          c.channels        = []
        end
      end
  end

  subject { described_class.new(bot) }

  before { bot.loggers.level = :fatal }
end
