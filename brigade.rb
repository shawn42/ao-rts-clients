class Brigade
  attr_accessor :resource, :path, :units
  def initialize(resource, map, base)
    @resource = resource
    @units = []
    @map = map
    b_vec = vec(base.x, base.y)
    @t_vec = vec(resource.x, resource.y)
    @path = Pathfinder.path(nil, @map, b_vec, @t_vec, 1, 10_000, false, "brigade: #{object_id}").reverse
    # NOTE if the path is even length; unit will need to stand on the base
    @path << vec(0,0) if @path.size.even?
    puts "building brigade: for #{reservation_token} with #{@path} and #{@units.map(&:id)}"
  end

  def reassign(unit)
    @units.delete(unit)
    loc = @path.shift
    @map.trans_at(loc.x, loc.y).reserved_for = nil
    loc = @path.shift
    @resource = loc
    @map.trans_at(loc.x, loc.y).reserved_for = nil

    if needs_help?
      add_unit(unit)
      true
    else
      false
    end
  end

  def reservation_token
    "brigade: #{object_id}"
  end

  def add_unit(unit)
    @units << unit
    puts "adding unit #{unit.id} to brigade w target: #{@t_vec}, now had #{@units.size} units"
  end

  def destroy!
    @units.each do |u|
      brigade_strat = u.strategy
      # brigade_strat.brigade = nil
      brigade_strat.target = vec(0,0)
      brigade_strat.state = :moving
    end
    @path.each do |loc|
      @map.trans_at(loc.x, loc.y).reserved_for = nil
    end
  end

  def done?
    return false if location_has_resource?(@resource)

    @path.each_with_index do |loc, i|
      return false if location_has_resource?(loc)
      u = @units[i]
      return false if u && unit_has_resource?(u)
    end
    puts "#{reservation_token} is done!"
    true
  end

  # def remove_unit(unit)
  #   @units.delete(unit)
  # end

  def trim!
    # TODO 
    # look on our path and map to figure out where the farthest resource on the path is
  end

  def previous_unit(unit)
    n = @units.index(unit)
    @units[n-1]
  end

  def unit_done?(unit)
    done = if unit == @units.first
      !unit_has_resource?(unit) && !location_has_resource?(@resource)
    else
      prev_unit = previous_unit(unit)
      !unit_has_resource?(unit) && !location_has_resource?(gather_loc(unit)) && unit_done?(prev_unit)
    end

    puts "unit #{unit.id} done? #{done}"
    done
  end

  def location_has_resource?(loc)
    loc && (@map.trans_at(loc.x, loc.y).resources&.total || 0) > 0
  end

  def unit_has_resource?(unit)
    (unit.resource || 0) > 0 
  end

  def dir_to_gather(unit)
    target = gather_loc(unit)
    Pathfinder.dir_toward(unit, target)
  end

  def gather_loc(unit)
    pos_in_line = @units.index(unit)
    i = spot_for_nth_worker(pos_in_line)-1
    unit == @units.first ? vec(@resource.x, @resource.y) : @path[i % @path.size]
  end

  def dir_to_drop(unit)
    pos_in_line = @units.index(unit)
    return nil if unit == @units.last

    i = spot_for_nth_worker(pos_in_line)+1
    target = @path[i % @path.size]
    Pathfinder.dir_toward(position_for(unit), target)
  end

  def position_for(unit)
    pos_in_line = @units.index(unit)
    i = spot_for_nth_worker(pos_in_line) % @path.size
    res = @path[i]
    res
  end

  def needs_help?
    @path.nil? || max_workers > @units.size
  end

  def max_workers
    path.size / 2 + 1
  end

  private
  def spot_for_nth_worker(n)
    n*2
  end
end