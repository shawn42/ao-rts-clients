require_relative '../unit_manager'

# main idea: collect as quickly as we can
class BrigadeUnitManager < UnitManager
  attr_reader :brigades

  def initialize(game_info, map)
    super
    @brigades = []
    @max_brigade_workers_needed = 0
  end

  def should_build_scout?
    workers = units_by_type("worker").select(&:alive?)
    scouts = units_by_type("scout").select(&:alive?)

    # TODO factor in unexplored cell count
    @map.resource_tiles.size < workers.size && scouts.size < 1
  end
  def should_build_tank?
    # return false
    turn > 400 && units_by_type("tank").select(&:alive?).size < 1
  end

  def clear_finished_brigades!
    # trying to run N brigades at once...
    @max_brigade_workers_needed = @brigades.map(&:max_workers).sum
    @brigades.each do |brigade|
      brigade.destroy! if brigade.done? || brigade.stalled?
    end
    @brigades.reject!(&:done?)
    @brigades.reject!(&:stalled?)
  end


  def should_build_worker?
    current_workers = units_by_type("worker").select(&:alive?).size
    return false if current_workers >= 17 # ~16 seems optimal
    @max_brigade_workers_needed+1 > current_workers
  end

  def update_overall_strategy
    workers = units_by_type("worker").select(&:alive?)
    tank_count = units_by_type("tank").select(&:alive?).size
    scout_count = units_by_type("scout").select(&:alive?).size

    worker_count = workers.size
    if should_build_scout?
      base.strategy = BuildIfYouCan.new(:scout, @map, base, self)
    elsif should_build_tank?
      base.strategy = BuildIfYouCan.new(:tank, @map, base, self)
    elsif should_build_worker?
      base.strategy = BuildIfYouCan.new(:worker, @map, base, self)

    else
      base.strategy = Noop.new(@map, base, self)
    end
  end

  def set_strategy(map, u)
    if u.type == 'base'
      u.strategy = BuildIfYouCan.new(:worker, map, u, self)
    elsif u.type == 'scout'
      u.strategy = ExploreTheUnknown.new(map, u, self)
    elsif u.type == 'tank'
      u.strategy = ProtectBase.new(map, u, self)
    elsif u.type == 'worker'
      u.strategy = BucketBrigadeCollector.new(map, u, self)
      # u.strategy = CompositeStrategy.new(
      #   1 => DefendBase.new(map, u, self),
      #   # 2 => RunAwayScared.new(map, u, self),
      #   3 => BucketBrigadeCollector.new(map, u, self)
      # )

      # u.strategy = CompositeStrategy.new(
      #   1 => RunAwayScared.new(map, u, self),
      #   # 1 => AttackIfHurt.new(map, u, self),
      #   2 => CollectNearestResource.new(map, u, self)
      # )
    end
  end
end