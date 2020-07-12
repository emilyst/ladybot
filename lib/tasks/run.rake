# frozen_string_literal: true

require 'ladybot'

desc 'Run the bot locally, connecting on port 6697 using SSL'
task :run, %i[nick server channels] => [:environment] do |_task, task_args|
  usage = <<~USAGE
    Usage: #{File.basename($PROGRAM_NAME)} run[ladybot_,irc.example.org,#]

      ...or...

    Usage: #{File.basename($PROGRAM_NAME)} run[ladybot_,irc.example.org,#:#2:#3]
  USAGE

  if task_args.nick.nil? || task_args.server.nil? || task_args.channels.nil?
    puts usage
    exit 1
  else
    nick = task_args.nick
    server = task_args.server
    channels = task_args.channels.split(/:/)

    if channels.empty?
      puts usage
      exit 1
    end

    args = [].push('--nick', nick).push('--server', server)
    channels.each { |c| args.push('--channel', c) }

    Ladybot::Bot.new(args).start!
  end
end
