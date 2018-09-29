require 'ladybot/version'
require 'ladybot/bot'

# load plugins
Dir[File.join(__dir__, 'ladybot', 'plugin', '*')].each { |file| require file }
