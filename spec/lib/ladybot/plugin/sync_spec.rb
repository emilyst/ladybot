# frozen_string_literal: true

describe Ladybot::Plugin::Sync do
  include_context 'plugin context'

  describe 'add regular command' do
    let(:message) do
      Cinch::Message.new(":#{nick}!user@duckberg.org PRIVMSG #{channel} :remove me", bot)
    end

    before { subject.regulars[channel] = %w[huey dewey louie] }

    context 'when called by someone who is not already a regular' do
      it 'adds the user' do
        subject.add_regular(message, args)
        expect(subject.regulars).to eq({ channel => ['huey', 'dewey', 'louie', nick] })
      end

      it 'tells the user they have been added' do
        expect(message)
          .to receive(:reply)
                .with(/#{nick}, you've been added to this channel's regular sync participants!/)

        subject.add_regular(message, args)
      end
    end

    context 'when called by someone who is already a regular' do
      before { subject.regulars[channel].push(nick) }

      it 'does not add the user as a regular again' do
        subject.add_regular(message, args)
        expect(subject.regulars).to eq({ channel => ['huey', 'dewey', 'louie', nick] })
      end

      it 'tells the user they have been already been added' do
        expect(message)
          .to receive(:reply)
                .with(/#{nick}, you're already a regular\./)

        subject.add_regular(message, args)
      end
    end
  end

  describe 'remove regular command' do
    let(:message) do
      Cinch::Message.new(":#{nick}!user@duckberg.org PRIVMSG #{channel} :remove me", bot)
    end

    before { subject.regulars[channel] = %w[huey dewey louie] }

    context 'when called by someone who is a regular' do
      before { subject.regulars[channel].push(nick) }

      it 'removes the user' do
        subject.remove_regular(message, args)
        expect(subject.regulars).to eq({ channel => %w[huey dewey louie] })
      end

      it 'tells the user they have been removed' do
        expect(message)
          .to receive(:reply)
                .with(/#{nick}, you've been removed from this channel's regular sync participants!/)

        subject.remove_regular(message, args)
      end
    end

    context 'when called by someone who is already not a regular' do
      it 'leaves the existing regulars alone' do
        subject.remove_regular(message, args)
        expect(subject.regulars).to eq({ channel => %w[huey dewey louie] })
      end

      it 'tells the user they were not a regular' do
        expect(message)
          .to receive(:reply)
                .with(/#{nick}, you weren't a regular in the first place\./)

        subject.remove_regular(message, args)
      end
    end
  end

  describe '#notify_regulars' do
    context 'regulars exist' do
      before { subject.regulars[channel] = %w[huey dewey louie] }

      it 'tells the regulars' do
        expect(channel_helper_response)
          .to receive(:send)
                .with(/Hey, huey, dewey, louie, a new sync just started./)

        subject.notify_regulars(channel, nick)
      end

      context 'when triggered by one of the regulars' do
        before { subject.regulars[channel] = %w[scrooge huey dewey louie] }

        it 'does not notify the regular who sent the notification' do
          expect(channel_helper_response)
            .to receive(:send)
                  .with(/Hey, huey, dewey, louie, a new sync just started./)

          subject.notify_regulars(channel, nick)
        end

        context 'when the only regular is the one who triggered the sync' do
          before { subject.regulars[channel] = %w[scrooge] }

          it 'sends no message to the channel' do
            expect(channel_helper_response).not_to receive(:send)
            subject.notify_regulars(channel, nick)
          end
        end
      end
    end

    context 'regulars do not exist' do
      it 'sends no message to the channel' do
        expect(channel_helper_response).not_to receive(:send)
        subject.notify_regulars(channel, nick)
      end
    end
  end

  describe 'sync command' do
    let(:message) { Cinch::Message.new(":#{nick}!user@duckberg.org PRIVMSG #{channel} :sync", bot) }

    before { allow(message).to receive(:reply) }

    it 'registers a handler for messages containing the command' do
      expect(described_class.matchers).to include(have_attributes(pattern: /^sync/, method: :sync))
    end

    it 'retrieves the appropriate handler for messages containing the command' do
      expect(subject.bot.handlers.find(:message, message).first).to be_a_kind_of(Cinch::Handler)
      expect(subject.bot.handlers.find(:message, message).first).to satisfy do |handler|
        expect(handler.pattern.pattern).to eq(/^sync/)
        expect(message).to receive(:reply)
        handler.block.call(message, args)
      end
    end

    context 'when called once' do
      it 'tells the channel about the sync' do
        expect(message).to receive(:reply).with(/#{nick} has started a sync/)
        subject.sync(message, args)
      end

      it 'sets up five-minute timer' do
        expect(subject).to receive(:Timer).with(5 * 60, shots: 1).and_call_original
        subject.sync(message, args)

        # it sets up a timer that kicks off in five minutes...
        expect(subject.timers).to include(a_kind_of(Cinch::Timer))
        expect(subject.timers).to include(have_attributes(interval: 5 * 60))

        # ...and when it does, it begins the countdown
        expect(subject).to receive(:countdown)
        subject.timers.first.block.call
      end

      it 'creates an ongoing sync' do
        subject.sync(message, args)

        expect(subject.ongoing_syncs)
          .to include(channel => {
                        participants: [nick],
                        timers: [a_kind_of(Cinch::Timer)],
                      })
      end

      context 'when regulars exist' do
        before do
          subject.regulars[channel] = %w[huey dewey louie]
          allow(subject).to receive(:Timer) # ignore first timer
        end

        it 'queues up a notification for them too' do
          expect(subject).to receive(:Timer).with(0.5, shots: 1).and_call_original
          subject.sync(message, args)

          # it sets up a timer that kicks off within the second...
          expect(subject.timers).to include(a_kind_of(Cinch::Timer))
          expect(subject.timers).to include(have_attributes(interval: 0.5))

          # ...and when it does, it notifies the regulars
          expect(subject).to receive(:notify_regulars).with(channel, nick)
          subject.timers.first.block.call
        end
      end
    end

    context 'when called again' do
      before do
        allow(subject).to receive(:Timer) # ignore first timer

        # the first call to begin the sync
        subject.sync(message, args)
      end

      context 'by a participant' do
        it 'announces the sync is starting early' do
          expect(message).not_to receive(:reply)
          subject.sync(message, args)
        end

        it 'sets of a second, instant timer which calls the countdown' do
          expect(subject).to receive(:Timer).with(0.5, shots: 1).and_call_original
          subject.sync(message, args)

          # it sets up a timer that kicks off within the second...
          expect(subject.timers).to include(a_kind_of(Cinch::Timer))
          expect(subject.timers).to include(have_attributes(interval: 0.5))

          # ...and when it does, it calls the countdown
          expect(subject).to receive(:countdown)
          subject.timers.first.block.call
        end

        it 'does not change the ongoing sync participants' do
          subject.ongoing_syncs[channel][:participants] << 'should_not_disappear'

          subject.sync(message, args)

          expect(subject.ongoing_syncs).to include({
                                                     channel => hash_including(participants: [nick, 'should_not_disappear']),
                                                   })
        end
      end

      context 'by a regular' do
        let(:huey) { 'huey' }
        let(:message_from_regular) do
          Cinch::Message.new(":#{huey}!#{huey}@duckberg.gov PRIVMSG #{channel} :sync", bot)
        end

        before do
          subject.regulars[channel] = %w[huey dewey louie]
        end

        it 'announces the sync is starting early' do
          expect(message_from_regular).not_to receive(:reply)
          subject.sync(message_from_regular, args)
        end

        it 'sets of a second, instant timer which calls the countdown' do
          expect(subject).to receive(:Timer).with(0.5, shots: 1).and_call_original
          subject.sync(message_from_regular, args)

          # it sets up a timer that kicks off within the second...
          expect(subject.timers).to include(a_kind_of(Cinch::Timer))
          expect(subject.timers).to include(have_attributes(interval: 0.5))

          # ...and when it does, it calls the countdown
          expect(subject).to receive(:countdown)
          subject.timers.first.block.call
        end

        it 'does not change the ongoing sync participants' do
          subject.ongoing_syncs[channel][:participants] << 'should_not_disappear'

          subject.sync(message_from_regular, args)

          expect(subject.ongoing_syncs).to include({
                                                     channel => hash_including(participants: [nick, 'should_not_disappear']),
                                                   })
        end
      end

      context 'by a non-participant' do
        let(:huey) { 'huey' }
        let(:non_participant_message) do
          Cinch::Message.new(":#{huey}!#{huey}@duckberg.gov PRIVMSG #{channel} :sync", bot)
        end

        before do
          allow(non_participant_message).to receive(:reply)
        end

        it 'does not send sync announcement' do
          expect(non_participant_message).not_to receive(:reply)
          subject.sync(message, args)
        end

        it 'does not set up a second, instant timer on the second call' do
          expect(subject).not_to receive(:Timer)

          subject.sync(non_participant_message, args)

          expect(subject.timers).to be_none
        end

        it 'does not change the ongoing sync participants' do
          subject.sync(non_participant_message, args)

          expect(subject.ongoing_syncs).to include({
                                                     channel => hash_including(participants: [nick]),
                                                   })
        end

        it 'warns the non-participant they cannot start the sync' do
          expect(non_participant_message)
            .to receive(:reply)
                  .with(/#{huey}, there's already a sync going on./)
          subject.sync(non_participant_message, args)
        end
      end
    end
  end

  describe 'rdy command' do
    let(:message) { Cinch::Message.new(":#{nick}!#{nick}@duckberg.org PRIVMSG #{channel} :rdy", bot) }

    it 'registers a handler for messages containing the command' do
      expect(described_class.matchers).to include(have_attributes(pattern: /^r(ea)?dy$/, method: :rdy))
    end

    it 'retrieves the appropriate handler for messages containing the command' do
      expect(subject.bot.handlers.find(:message, message).first).to be_a_kind_of(Cinch::Handler)
      expect(subject.bot.handlers.find(:message, message).first).to satisfy do |handler|
        expect(handler.pattern.pattern).to eq(/^r(ea)?dy$/)
        expect(message).to receive(:reply)
        handler.block.call(message, args)
      end
    end

    context 'when the text "rdy" is followed by more text' do
      let(:message) { Cinch::Message.new(":#{nick}!#{nick}@duckberg.org PRIVMSG #{channel} :rdy player one", bot) }

      it 'retrieves no handler for the message' do
        expect(subject.bot.handlers.find(:message, message)).to be_empty
      end
    end

    context 'when "ready" is spelled out fully' do
      let(:message) { Cinch::Message.new(":#{nick}!#{nick}@duckberg.org PRIVMSG #{channel} :ready", bot) }

      it 'retrieves the appropriate handler for messages containing the command' do
        expect(subject.bot.handlers.find(:message, message).first).to be_a_kind_of(Cinch::Handler)
        expect(subject.bot.handlers.find(:message, message).first).to satisfy do |handler|
          expect(handler.pattern.pattern).to eq(/^r(ea)?dy$/)
          expect(message).to receive(:reply)
          handler.block.call(message, args)
        end
      end
    end

    context 'with no ongoing sync for the current channel' do
      it 'prompts to begin a sync' do
        expect(message).to receive(:reply).with(/Sorry, #{nick}, there's no sync/)
        subject.rdy(message, args)
      end

      it 'does not create an ongoing sync' do
        subject.rdy(message, args)
        expect(subject.ongoing_syncs).to include({ channel => {}})
      end
    end

    context 'with an ongoing sync for the current channel' do
      before { subject.ongoing_syncs[channel] = { participants: [nick] } }

      context 'from the user who began the sync' do
        it 'warns the user' do
          expect(message).to receive(:reply)
                               .with(/Sorry, #{nick}, you're already in the sync/)
          subject.rdy(message, args)
        end
      end

      context 'from another user in the channel' do
        let(:huey) { 'huey' }
        let(:message) { Cinch::Message.new(":#{huey}!#{huey}@duckberg.org PRIVMSG #{channel} :rdy", bot) }

        it 'adds the user to the sync' do
          subject.rdy(message, args)
          expect(subject.ongoing_syncs).to include(channel => { participants: [nick, 'huey'] })
        end

        it 'tells the user they are in the sync' do
          expect(message).to receive(:reply)
                               .with(/#{huey}, you've been added to the sync/)
          subject.rdy(message, args)
        end
      end
    end

    context 'with an ongoing sync for another channel' do
      before do
        subject.ongoing_syncs['#another_channel'] = {
          participants: [nick],
          timers: [Cinch::Timer.new(bot, {}) {}],
        }
      end

      it 'prompts to begin a sync' do
        expect(message).to receive(:reply).with(/Sorry, #{nick}, there's no sync/)
        subject.ongoing_syncs['#another_channel'] = [nick]
        subject.rdy(message, args)
      end

      it 'does not create an ongoing sync in that channel' do
        subject.rdy(message, args)
        expect(subject.ongoing_syncs).to include({ channel => {}})
      end
    end
  end

  describe 'go command' do
    let(:message) { Cinch::Message.new(":#{nick}!#{nick}@duckberg.org PRIVMSG #{channel} :go", bot) }

    before do
      subject.ongoing_syncs[channel] = { participants: [nick], timers: [Cinch::Timer.new(bot, {}) {}] }
    end

    it 'registers a handler for messages containing the command' do
      expect(described_class.matchers).to include(have_attributes(pattern: /^go\b/, method: :go))
    end

    it 'retrieves the appropriate handler for messages containing the command' do
      expect(subject.bot.handlers.find(:message, message).first).to be_a_kind_of(Cinch::Handler)
      expect(subject.bot.handlers.find(:message, message).first).to satisfy do |handler|
        expect(handler.pattern.pattern).to eq(/^go\b/)
        expect(subject).to receive(:sync).with(message, args)
        handler.block.call(message, *args)
      end
    end

    context 'when "go" occurs within a larger word' do
      let(:message) { Cinch::Message.new(":#{nick}!#{nick}@duckberg.org PRIVMSG #{channel} :gonorrhea", bot) }

      it 'retrieves no handler for the message' do
        expect(subject.bot.handlers.find(:message, message)).to be_empty
      end
    end
  end

  describe '#countdown' do
    context 'with no ongoing sync for the current channel' do
      it 'does nothing' do
        expect(subject).not_to receive(:Channel)
        expect(subject.countdown(channel)).to be(nil)
      end
    end

    context 'with an ongoing sync for the current channel' do
      context 'when the timer has expired' do
        let(:timer) { Cinch::Timer.new(bot, { interval: 300, shots: 1 }) {} }

        before do
          # add other participants to the sync
          subject.ongoing_syncs[channel] = {
            participants: [nick, 'huey', 'dewey', 'louie'],
            timers: [timer],
          }
        end

        it 'removes the ongoing sync' do
          subject.countdown(channel)
          expect(subject.ongoing_syncs).to include({ channel => {}})
        end

        it 'stops the timer' do
          expect(timer.stopped?).to be(true)
        end

        it 'announces the countdown to all participants' do
          expect(channel_helper_response).to receive(:send)
                                               .with(/Hey, #{nick}, huey, dewey, louie, it's time to sync/)

          subject.countdown(channel)
        end

        context 'when there are regulars' do
          before { subject.regulars[channel] = %w[donald daisy] }

          it 'announces to regulars too' do
            expect(channel_helper_response).to receive(:send)
                                                 .with(/Hey, #{nick}, huey, dewey, louie, donald, daisy, it's time to sync/)

            subject.countdown(channel)
          end
        end
      end

      context 'when the timer was preempted' do
        let(:original_timer) { Cinch::Timer.new(bot, { interval: 300, shots: 1 }) {} }
        let(:short_circuit_timer) { Cinch::Timer.new(bot, { interval: 0.5, shots: 1 }) {} }

        before do
          # simulate an early sync
          subject.ongoing_syncs[channel] = {
            participants: [nick],
            timers: [original_timer, short_circuit_timer],
          }
        end

        it 'removes the ongoing sync' do
          subject.countdown(channel)
          expect(subject.ongoing_syncs).to include({ channel => {}})
        end

        it 'stops the original timer' do
          expect(original_timer.stopped?).to be(true)
        end

        it 'stops the new short circuit timer' do
          expect(short_circuit_timer.stopped?).to be(true)
        end

        it 'announces the countdown to all participants' do
          expect(channel_helper_response).to receive(:send)
                                               .with(/Hey, #{nick}, it's time to sync/)

          subject.countdown(channel)
        end

        context 'when there are regulars' do
          before { subject.regulars[channel] = %w[huey dewey louie] }

          it 'announces to regulars too' do
            expect(channel_helper_response).to receive(:send)
                                                 .with(/Hey, #{nick}, huey, dewey, louie, it's time to sync/)

            subject.countdown(channel)
          end
        end
      end
    end

    context 'with an ongoing sync for another channel' do
      before { subject.ongoing_syncs['#another_channel'] = [nick] }

      it 'does nothing' do
        expect(subject).not_to receive(:Channel)
        expect(subject.countdown(channel)).to be(nil)
      end
    end
  end
end
