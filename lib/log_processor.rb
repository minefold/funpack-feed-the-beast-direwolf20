# encoding: UTF-8

require 'time'

class LogProcessor
  def initialize(pid, schema)
    @pid = pid
    @listing = false
    @schema = schema
  end

  def event type, options = {}
    {
      ts: Time.now.utc.iso8601,
      event: type
    }.merge(options)
  end

  def terminate!
    Thread.new do
      puts JSON.dump event('error', msg: "terminating #{@pid}")
      sleep 5
      Process.kill :KILL, @pid
    end
  end

  def process_line(line)
    line = line.force_encoding('ISO-8859-1').
      gsub(/\u001b\[(m|\d+;\dm)?/, ''). # strip color sequences out
      gsub(/^[\d-]+ [\d:]+\s/, ''). # strip time prefix
      gsub(/\[INFO\] /, '').strip # strip [INFO]

    result = if @listing
      process_list_line(line)
    else
      process_regular_line(line)
    end
  end

  def process_regular_line(line)
    case line
    when /Done \(/
      event 'started'

    when /^\[\w+\] <([\w;_~]+)> (.*)$/
      event 'chat', nick: $1, msg: $2

    when 'Stopping server'
      event 'stopping'

    when /^\[\w+\] (\w+).*logged in with entity id/
      event 'player_connected', auth: 'mojang', uid: $1

    when /^\[\w+\] (\w+) lost connection: (.*)$/
      event 'player_disconnected', auth: 'mojang', uid: $1, reason: $2

    when /^\[\w+\] \[(\w+): ([\w-]+) (.+)\]$/
      process_setting_changed $1, $2, $3

    when /FAILED TO BIND TO PORT!/
      terminate!
      event 'fatal_error', reason: 'port_bind_failed'

    when /^\[SEVERE\] java.lang.OutOfMemoryError/
      terminate!
      event 'fatal_error', reason: 'out_of_memory'

    when /^\[SEVERE\] The server has stopped responding!/
      terminate!
      event 'fatal_error', reason: line

    when /^\[SEVERE\] \[Minecraft\] This crash report has been saved to/
      terminate!
      event 'fatal_error', reason: line
      
    when /^\[SEVERE\] \[Minecraft\] Could not save crash report to/
      terminate!
      event 'fatal_error', reason: line

    when /^\[\w+\] There are (\d+)\/\d+ players online:$/
      @player_count = $1.to_i
      if @player_count == 0
        event 'players_list', auth: 'mojang', uids: []
      else
        @listing = true
        nil
      end

    else
      event 'info', msg: line
    end
  end

  def process_list_line(line)
    @listing = false
    event 'players_list', auth: 'mojang', uids: line.gsub(/\[\w+\] /,'').split(",")
  end

  def process_setting_changed(actor, action, target)
    setting = {
      'Opped'    => { add: 'ops', value: target },
      'De-opped' => { remove: 'ops', value: target },
      'Added'    => { add: 'whitelist', value: target.split(' ').first },
      'Removed'  => { remove: 'whitelist', value: target.split(' ').first },
      'Banned'   => { add: 'blacklist', value: target.split(' ').last },
      'Unbanned' => { remove: 'blacklist', value: target.split(' ').last },
    }[action]

    if setting
      event 'settings_changed', setting.merge(actor: actor)
    else
      case action
      when 'Set'
        if target =~ /game difficulty to (\w+)/
          field = @schema.fields.find{|f| f.name == :difficulty }
          value = field.values.find{|v| v['label'] == $1 }
          event 'settings_changed',
            actor: actor,
            set: 'difficulty',
            value: value['value']
        end
      end
    end
  end
end
