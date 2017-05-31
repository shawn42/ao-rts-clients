require_relative '../unit_manager'

# main idea: collect as quickly as we can
class CollectUnitManager < UnitManager
  def update_overall_strategy
    workers = units_by_type("worker").select(&:alive?)
    tank_count = units_by_type("tank").select(&:alive?).size
    scout_count = units_by_type("scout").select(&:alive?).size

    worker_count = workers.size
    if worker_count < 10 #10
      base.strategy = BuildIfYouCan.new(:worker, @map, base, self)
    elsif scout_count < 1
      base.strategy = BuildIfYouCan.new(:scout, @map, base, self)
    elsif worker_count < 22 #22
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
    elsif u.type == 'worker'
      # explorer = units_by_type("worker").select(&:alive?).first
      # if explorer.nil?
      #   u.strategy = Explore.new(map, u, self)
      # else
        u.strategy = CollectNearestResource.new(map, u, self)
      # end
    end
  end
end