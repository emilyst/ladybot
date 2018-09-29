describe Ladybot::Bot do
  it 'configures a Cinch bot' do
    expect(described_class.new.cinch_bot).to be_a_kind_of(Cinch::Bot)
  end

  it 'configures plugins' do
    expect(described_class.new.plugins).to satisfy do |plugins|
      plugins.map { |plugin| plugin.included_modules.include?(Cinch::Plugin) }.all?
    end
  end
end
