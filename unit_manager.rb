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
  
  def update(updates, turn)
    (updates.unit_updates || []).each do |uu|
      u = @units[uu.id] || Unit.new
      # $debug_file ||= File.open('debug.txt','w+')
      # $debug_file.puts "unit #{uu.id} idle on turn #{turn}" if uu.status == 'idle'
      update_attrs(u, uu)
      next if uu.status == 'dead'
      set_strategy(@map, u) unless u.strategy
      @units[uu.id] = u
    end

    update_overall_strategy
  end

  def commands
    cmds = @units.values.flat_map(&:commands).compact
    cmds << {command: 'IDENTIFY', name: self.class.name}
    cmds
  end

  def update_strategies
    t = Time.now
    @units.values.each do |u|
      if u.strategy
        u.strategy.update
      end
      elapsed_secs = Time.now - t
      break if elapsed_secs > 0.1
    end
  end

  private
  def update_attrs(u, attrs)
    attrs.each do |k,v|
      attr_name = "#{k}="
      u.send(attr_name, v) if u.respond_to? attr_name
    end
  end
end
