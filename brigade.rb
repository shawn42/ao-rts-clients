class Brigade
  attr_accessor :resource, :path, :units, :last_progressed_turn 
  def initialize(resource, map, unit_manager)
    @resource = resource
    @units = []
    @map = map
    @unit_manager = unit_manager
    base = unit_manager.base
    @last_progressed_turn = unit_manager.turn
    b_vec = vec(base.x, base.y)
    @t_vec = vec(resource.x, resource.y)
    @path = Pathfinder.path(nil, @map, b_vec, @t_vec, close_enough: 1, max_steps: 10_000, translate_to_moves: false, reservation_token: reservation_token)&.reverse || []
    # puts "building brigade: for #{reservation_token} with #{@path}"
    raise "OH NO!: no path found from #{b_vec} to #{@t_vec}!" unless @path.size > 1

    @path.each do |loc|
      @unit_manager.units.values().select{|u| u.type == "worker"}.each do |u|
        if (u.x != 0 && u.y != 0) && u.x == loc.x && u.y == loc.y
          # Try to move this unit out of the way!
          brigade_strat = u.strategy
          if brigade_strat.brigade.nil?
            puts "!!! Trying to redirect a stalled unit!"
            brigade_strat.target = vec(0,0)
            brigade_strat.state = :moving
          else
            # puts "#{u.id} [#{u.x}, #{u.y}] is on the path at loc: [#{loc.x},#{loc.y}]!"
            # puts "PATH: #{path}"
            raise "OH NO!: units in the way: #{u.id}"
          end
        end
      end
    end
    # NOTE if the path is even length; unit will need to stand on the base
    @path << vec(0,0) if @path.size.even?
    build_assignments
  end

  def progress!
    @last_progressed_turn = @unit_manager.turn
  end

  def build_assignments
    reserve_slots
    avail_units = @unit_manager.units.values().select { |u| u.type == "worker" && u.strategy.brigade.nil? }.dup
    @slots.each do |slot|
      break if avail_units.empty?
      best_unit = avail_units.min_by{ |u| dist_apart(u, slot) }
      assign_unit(best_unit, slot)
      avail_units.delete(best_unit)
    end
    
  end

  def assign_unit(unit, slot)
    add_unit(unit)
    strat = unit.strategy
    strat.brigade = self
    strat.target = position_for(unit)
    strat.state = :moving
  end

  def dist_apart(loc1, loc2)
    # ignore the sqrt for now
    base_dx = (loc1.x-loc2.x).abs
    base_dy = (loc1.y-loc2.y).abs
    base_dy^2 + base_dx^2
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

  def reserve_slots
    @slots = @path.select.with_index { |_, i| i.odd? }
    slots = @slots.reject{|s|s.x == 0 && s.y == 0}
    slots.each do |loc|
      @map.reserve(loc.x, loc.y, reservation_token)
    end
  end

  def add_unit(unit)
    unit.token = reservation_token
    @units << unit
    # puts "adding unit #{unit.id} to brigade w target: #{@t_vec}, now had #{@units.size} units"
  end

  def destroy!
    @units.each do |u|
      u.token = nil
      brigade_strat = u.strategy
      brigade_strat.brigade = nil
      brigade_strat.target = vec(0,0)
      brigade_strat.state = :moving
    end
    @path.each do |loc|
      @map.release(loc.x, loc.y)
    end
  end

  def stalled?
    (@unit_manager.turn-@last_progressed_turn) > 80
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
    if vec(unit.x, unit.y) == vec(target.x, target.y)
      raise "OH NO!: invalid gather location: #{target}"
    end
    Pathfinder.dir_toward(unit, target)
  end

  def gather_loc(unit)
    pos_in_line = @units.index(unit)
    if pos_in_line
      i = spot_for_nth_worker(pos_in_line)-1
      unit == @units.first ? vec(@resource.x, @resource.y) : @path[i]
    else
      raise "not a valid unit for this brigade"
    end
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
    i = spot_for_nth_worker(pos_in_line)
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