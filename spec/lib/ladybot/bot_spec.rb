# frozen_string_literal: true

describe Ladybot::Bot do
  subject { described_class.new }

  it 'configures a Cinch bot' do
    expect(subject.cinch_bot).to be_a_kind_of(Cinch::Bot)
  end

  it 'configures plugins' do
    expect(subject.discover_plugins).to satisfy do |plugins|
      plugins.map { |plugin| plugin.included_modules.include?(Cinch::Plugin) }.all?
    end
  end
end
