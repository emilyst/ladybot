# frozen_string_literal: true

require 'ladybot/version'
require 'ladybot/bot'

# load plugins
Dir[File.join(__dir__, 'ladybot', 'plugin', '*.rb')].sort.each { |file| require file }
