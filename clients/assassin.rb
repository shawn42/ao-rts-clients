require_relative '../unit_manager'

# main idea: create a tank, locate base, park tank at base
class AssassinUnitManager < UnitManager
  def update_overall_strategy
    worker_count = units_by_type("worker").size
    tank_count = units_by_type("tank").size
    scout_count = units_by_type("scout").size

    # 12,21 3300
    if worker_count < 12 
      base.strategy = BuildIfYouCan.new(:worker, @map, base, self)
    elsif scout_count < 1
      base.strategy = BuildIfYouCan.new(:scout, @map, base, self)
    elsif tank_count < 1
      base.strategy = BuildIfYouCan.new(:tank, @map, base, self)
    elsif worker_count < 21
      base.strategy = BuildIfYouCan.new(:worker, @map, base, self)
    else
      base.strategy = Noop.new(@map, base, self)
    end
  end

  def set_strategy(map, u)
    if u.type == 'base'
      u.strategy = BuildIfYouCan.new(:tank, map, u, self)
    elsif u.type == 'scout'
      u.strategy = ExploreTheUnknown.new(map, u, self)
    elsif u.type == 'tank'
      u.strategy = FrontierPatrol.new(map, u, self)
    elsif u.type == 'worker'
      u.strategy = CollectNearestResource.new(map, u, self)
    end
  end
end