class UnitManager
  attr_reader :units
  def initialize(game_info, map)
    @game_info = game_info
    @map = map
    @units = {}
    @res_assignments ||= {}
  end

  def unit(id)
    @units[id]
  end

  def base
    @base ||= @units.values.find{|u|u.type == "base"}
  end

  def resource_assignments(id)
    @res_assignments[id] ||= Set.new
  end

  def assign_resource(unit, id)
    @res_assignments[id] ||= Set.new
    @res_assignments[id] << unit
  end

  def unassign_resource(unit, id)
    @res_assignments[id] ||= Set.new
    @res_assignments[id].delete unit
  end

  def units_by_type(type)
    @units.values.select{|u|u.type == type}
  end

  def update_overall_strategy
    raise "OH NOES"
  end
  def set_strategy(map, u)
  end
  
  def update(updates)
    (updates.unit_updates || []).each do |uu|
      u = @units[uu.id] || Unit.new
      update_attrs(u, uu)
      set_strategy(@map, u) unless u.strategy
      @units[uu.id] = u
    end

    update_overall_strategy
  end

  def commands
    @units.values.map(&:command).compact
  end

  def update_strategies
    @units.values.each do |u|
      if u.strategy
        u.strategy.update
      end
    end
  end

  private
  def update_attrs(u, attrs)
    attrs.each do |k,v|
      u.send("#{k}=", v)
    end
  end
end