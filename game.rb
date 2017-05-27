require_relative './lib/hash_object'

class Unit
  attr_accessor :id, :type, :status, :x, :y, :can_attack, :health, :resource, :player_id,
    :strategy
  def command
    if @strategy && @strategy.has_command?
      @strategy.command
    end
  end
end

class Tile
  attr_accessor :blocked, :resources, :units, :status, :visible, :x, :y
  def initialize
    @units = []
    @status = :unknown
  end
end

class Game
  attr_reader :unit_manager, :map
  WORKER_COST = 100
  SCOUT_COST = 130
  TANK_COST = 150
  COSTS = {
    worker: 100,
    scout: 130,
    tank: 150,
  }
  DIR_VECS = {
    'N' => vec(0,-1),
    'S' => vec(0,1),
    'W' => vec(-1,0),
    'E' => vec(1,0),
  }
  VEC_DIRS = {
    vec(0,-1) => ['N'],
    vec(0,1) => ['S'],
    vec(-1,0) => ['W'],
    vec(1,0) => ['E'],
    vec(1,1) => ['S','E'],
    vec(-1,1) => ['S', 'W'],
    vec(1,-1) => ['N', 'E'],
    vec(-1,-1) => ['N', 'W'],
  }

  def initialize(manager_klass)
    puts manager_klass
    @manager_klass = manager_klass
  end
  def setup(msg)
    @game_info = HashObject.new width: 32, height: 32
    @map = Map.new @game_info
    @unit_manager = @manager_klass.new @game_info, @map
  end

  def update(update_obj)
    @game_info[:player_id] ||= update_obj.player_id
    @game_info[:total_time] ||= update_obj.time
    @game_info[:time_remaining] = update_obj.time

    @map.update(update_obj)
    @unit_manager.update(update_obj)
  end

  def generate_commands
    @unit_manager.update_strategies
    cmds = @unit_manager.commands.compact
    # puts cmds.inspect unless cmds.empty?
    {commands: cmds}
  end
end