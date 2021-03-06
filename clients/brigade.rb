require_relative '../unit_manager'

# main idea: collect as quickly as we can
class BrigadeUnitManager < UnitManager
  def should_build_scout?
    workers = units_by_type("worker").select(&:alive?)
    scouts = units_by_type("scout").select(&:alive?)

    # TODO factor in unexplored cell count
    @map.resource_tiles.size < workers.size && scouts.size < 1
  end
  def should_build_tank?
    return false
    units_by_type("tank").select(&:alive?).size < 1
  end

  def should_build_worker?
    return false
    res = BucketBrigadeCollector.best_resource(vec(0,0), self, @map)
    if res
      path = Pathfinder.path(units, @map, vec(0,0), vec(res.x, res.y))
      if path
        build_worker_turns = 5
        turns_per_move = 5
        cost_of_worker = 100
        roundtrip_turns = path.size*2*turns_per_move+1
        val = res.resources.value
        total = res.resources.total

        trips_to_pay_off = cost_of_worker.to_f / val
        ms_per_turn = 200
        turns_left = @game_info[:time_remaining] / ms_per_turn

        return total > cost_of_worker && (trips_to_pay_off * roundtrip_turns) < turns_left
      end
    end
    false
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