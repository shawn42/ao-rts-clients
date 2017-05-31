require_relative '../unit_manager'

# main idea: send most workers to attack
class ZergUnitManager < UnitManager
  def update_overall_strategy
    worker_count = units_by_type("worker").size
    tank_count = units_by_type("tank").size
    scout_count = units_by_type("scout").size

    if worker_count > 18
      base.strategy = Noop.new(@map, base, self)
    end
  end

  def set_strategy(map, u)
    if u.type == 'base'
      u.strategy = BuildIfYouCan.new(:worker, map, u, self)
    elsif u.type == 'worker'
      # strat = [FrontierPatrol, CollectNearestResource].sample
      strat = EdgeExplore
      u.strategy = strat.new(map, u, self)
    end
  end
end