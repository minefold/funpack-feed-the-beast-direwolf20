require 'spec_helper'
require 'log_processor'
require 'brock'
require 'json'

RSpec::Matchers.define :match_event do |type, opts|
  match do |a|
    a.delete(:ts)
    { event: type }.merge(opts || {}) == a
  end
end

describe LogProcessor do
  let(:funpack_json) { JSON.parse(File.read('funpack.json')) }
  let(:schema) { Brock::Schema.new(funpack_json['schema']) }
  let(:processor) { LogProcessor.new(1, schema) }

  def process(input)
    events = input.strip.split("\n").map do |line|
      processor.process_line(line.strip)
    end
  end

  describe 'list' do
    context 'when empty' do
      it 'returns empty list' do
        events = process <<-EOS
          [Minecraft] There are 0/50 players online:
        EOS

        events[0].should match_event('players_list',
          auth: 'mojang',
          uids: []
        )
      end
    end

    it 'returns connected players' do
      events = process <<-EOS
        [Minecraft] There are 2/50 players online:
        [Minecraft] whatupdave,chrislloyd
      EOS

      events[1].should match_event('players_list',
        auth: 'mojang',
        uids: ['whatupdave', 'chrislloyd']
      )
    end
  end

  context 'settings changes' do
    {
      "[whatupdave: Opped someguy]" => { add: 'ops', value: 'someguy'},
      "[whatupdave: De-opped someguy]" => { remove: 'ops', value: 'someguy'},
      "[whatupdave: Added someguy to the whitelist]" => { add: 'whitelist', value: 'someguy'},
      "[whatupdave: Removed someguy from the whitelist]" => { remove: 'whitelist', value: 'someguy'},
      "[whatupdave: Banned player someguy]" => { add: 'blacklist', value: 'someguy'},
      "[whatupdave: Unbanned player someguy]" => { remove: 'blacklist', value: 'someguy'},
      "[whatupdave: Set game difficulty to Normal]" => { set: 'difficulty', value: '2'},
    }.each do |src, event|
      describe src do
        subject { process("[Minecraft] #{src}").first }
        it { should match_event 'settings_changed', event.merge(actor: 'whatupdave') }
      end
    end
  end
end
