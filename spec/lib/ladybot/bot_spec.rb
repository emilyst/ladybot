# frozen_string_literal: true

describe Ladybot::Bot do
  let(:args) { %w/ --server localhost / }

  subject { described_class.new(args) }

  it 'configures a Cinch bot' do
    expect(subject.bot).to be_a_kind_of(Cinch::Bot)
  end

  it 'configures plugins' do
    expect(subject.discover_plugins).to satisfy do |plugins|
      plugins.map { |plugin| plugin.included_modules.include?(Cinch::Plugin) }.all?
    end
  end

  context 'with long args' do
    let(:args) do
      %w/
        --server localhost
        --port 6697
        --ssl
        --nick scrooge
        --user mcduck
        --channel #duckberg
        --channel #scotland
      /
    end

    it 'parses the args' do
      expect(subject.parse(args)).to include(server:   'localhost',
                                             port:     6697,
                                             ssl:      true,
                                             nick:     'scrooge',
                                             user:     'mcduck',
                                             channels: ['#duckberg',
                                                        '#scotland'])
    end
  end

  context 'with short args' do
    let(:args) do
      %w/
        -s localhost
        -p 6697
        -S
        -n scrooge
        -u mcduck
        -c #duckberg
        -c #scotland
      /
    end

    it 'parses the args' do
      expect(subject.parse(args)).to include(server:   'localhost',
                                             port:     6697,
                                             ssl:      true,
                                             nick:     'scrooge',
                                             user:     'mcduck',
                                             channels: ['#duckberg',
                                                        '#scotland'])
    end
  end

  context 'with explicitly no SSL' do
    let(:args) do
      %w/
        --server localhost
        --no-ssl
      /
    end

    it 'parses the args' do
      expect(subject.parse(args)).to include(ssl: false)
    end
  end
end
