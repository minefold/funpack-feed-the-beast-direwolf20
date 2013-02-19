require 'find'
require 'nbtfile'

module Minecraft
  def self.find_root(path)
    if path = level_path(path)
      # server root will be one dir above level path
      File.expand_path('..', path)
    end
  end

  def self.level_dats(root)
    paths = []
    Find.find(root) do |path|
      if path =~ /\/(level|uid)\.dat$/
        paths << path
      end
    end
    paths
  end

  def self.read_settings(root)
    settings = {}
    begin
      nbt = NBTFile.read(File.open(level_dats('.').first))
      settings = {
        seed: nbt[1]['Data']['RandomSeed'].value.to_s
      }
    rescue
      # seed detection failed
    end
    settings
  end

  def self.level_paths(root)
    level_dats(root).map{|file| File.dirname(file).gsub(/^\.\//, '') }
  end

  def self.level_path(root)
    level_paths(root).min
  end

  def self.player_list(player_setting)
    # TODO remove this if when players are passed as an array
    if player_setting.is_a? Array
      player_setting.join("\n")
    else
      player_setting
    end
  end
end