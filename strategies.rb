class Strategy
  def initialize(map, unit, unit_manager)
    @map = map
    @unit = unit
    @unit_manager = unit_manager
    @units = unit_manager.units
  end
  def has_command?
    false
  end
  def update(*args)
  end
  def dir_toward_resource(u, r)
    dir = dir_toward(u, r.x,r.y)
    if dir == nil
      dir = Pathfinder.dir_toward(vec(u.x,u.y), vec(r.x,r.y)) if resource_adjacent?(u, r)
    end

    dir
  end
  def dir_toward_base(u)
    dir_toward(u, 0,0)#, 0) only needed if we have to walk under the base
  end
  def dir_toward(u, x,y, close_enough=1)
    if @path.nil? || @path.empty?
      @path = Pathfinder.path(@units, @map, vec(u.x,u.y), vec(x,y), close_enough) || []
    end
    @path.shift
  end

  def resource_adjacent?(u, r)
    dx = (r.x-u.x).abs
    dy = (r.y-u.y).abs
    (dx <= 1 && dy <= 1) && dx != dy
  end

  def resource_adjacent(u, r)
    u_vec = vec(u.x,u.y)
    current_value = r ? r.resources.value : 0
    Game::DIR_VECS.values.each do |v|
      n_loc = u_vec + v
      t = @map.trans_at(n_loc.x, n_loc.y)
      if t && t.resources && t.resources.value >= current_value
        return t
      end
    end
    nil
  end
  def gather_command(u, dir)
    {
      command: "GATHER",
      unit: u.id,
      dir: dir,
    }
  end
  def move_command(u, dir)
    {
      command: "MOVE",
      unit: u.id,
      dir: dir,
    }
  end
  def attack_command(u,tile)
    {
      command: "ATTACK",
      unit: u.id,
      dx: tile.x-u.x,
      dy: tile.y-u.y,
    }
  end
  def create_command(type)
    {
      command: "CREATE",
      type: type,
    }
  end
end

class Noop < Strategy
end

class BuildIfYouCan < Strategy
  def initialize(type, *args)
    @type = type
    super *args
  end
  def has_command?
    @unit.status == 'idle' && @unit.resource > Game::COSTS[@type]
  end
  def command
    create_command(@type)
  end
end

class CollectNearestResource < Strategy
  def has_command?
    @unit.status == 'idle'
  end

  def command
    if @unit.resource > 0
      move_command(@unit, dir_toward_base(@unit))
    else

      if @resource && @resource.resources.nil?
        @unit_manager.unassign_resource(@unit, @res_id)
        @resource = nil 
        @res_id = nil
      end
      @resource ||= best_resource(@unit)
      @res_id = @resource.resources.id if @resource
      adjacent_res = resource_adjacent(@unit, @resource)

      if @resource && adjacent_res
        @unit_manager.unassign_resource(@unit, @res_id)

        @resource = adjacent_res
        r = @resource
        u = @unit
        dir_vec = vec(r.x,r.y) - vec(u.x,u.y)
        # @unit_manager.unassign_resource(@unit, @res_id)
        @resource = nil
        @res_id = nil
        dir = dir_toward_resource(u, r)
        gather_command(@unit, dir) if dir
      elsif @resource
        @unit_manager.assign_resource(@unit, @res_id)
        dir = dir_toward_resource(@unit, @resource)
        if dir
          move_command(@unit, dir)
        else
          @resource = nil
          move_command(@unit, Game::DIR_VECS.keys.sample)
        end
      else
        # no resources? .. keep looking
        move_command(@unit, Game::DIR_VECS.keys.sample)
      end
    end
  end

  def best_resource(u)
    b = @unit_manager.units_by_type("base").first
    tiles = []
    @map.each_resource do |t|
      r = t.resources
      tiles << t if (r.total / r.value) > @unit_manager.resource_assignments(r.id).size
    end
    # sorted = tiles.sort_by do |t|
    #   dx = (t.x-u.x).abs
    #   dy = (t.y-u.y).abs

    #   base_dx = (t.x-b.x).abs
    #   base_dy = (t.y-b.y).abs

    #   total_dist = dx+dy+base_dx+base_dy
    #   value = t.resources.value
    #   value.to_f/total_dist 
    # end
    sorted = tiles.sort_by do |t|
      dx = (t.x-u.x).abs
      dy = (t.y-u.y).abs

      base_dx = (t.x-b.x).abs
      base_dy = (t.y-b.y).abs

      total_dist = dx+dy+base_dx+base_dy
      value = t.resources.value
      value.to_f/total_dist 
    end
    sorted = sorted.reverse[0..12].sort_by do |t|
      # u_vec = vec(u.x,u.y)
      t_vec = vec(t.x,t.y)
      b_vec = vec(b.x,b.y)

      # target_path = Pathfinder.path(@unit_manager.units, @map, u_vec, t_vec)
      base_path = Pathfinder.path(@unit_manager.units, @map, b_vec, t_vec)
      base_dist = base_path&.size || 9999
      # target_dist = target_path&.size || 9999
      # total_dist = target_dist + base_dist
      value = t.resources.value
      value.to_f/base_dist*2
    end
    sorted.last
  end
end

class MoveRandom < Strategy
  def has_command?
    @unit.status == 'idle'
  end
  def command
    move_command(@unit, Game::DIR_VECS.keys.sample)
  end
end

class EdgeExplore < Strategy
  def has_command?
    @unit.status == 'idle'
  end
  def command
    @dir ||= Game::DIR_VECS.keys.sample
    @num_steps ||= 0
    if (@last_x == @unit.x && @last_y == @unit.y) || @num_steps > 6
      # bumped or went far enough
      @dir = (Game::DIR_VECS.keys-[@dir]).sample
      @num_steps = 0
    end
    @num_steps += 1
    @last_x = @unit.x
    @last_y = @unit.y
    move_command(@unit, @dir)
  end
end

class ExploreTheUnknown < Strategy
  def has_command?
    @unit.status == 'idle'
  end
  def command
    return nil if @done
    if @target.nil?
      nearest = nearest_unknown(@map, @unit)
      if nearest
        @target = nearest - @map.offset
      else
        @done = true
        return nil
      end
    end
    @close ||= 1
    u_vec = vec(@unit.x, @unit.y)
    if @target
      @path ||= Pathfinder.path(@units, @map, u_vec, @target, @close)
      if @path
        dir = @path.shift
        if dir
          return move_command(@unit, dir)
        else
          @path = nil
          @target = nil
          @close = 1
        end
      else
        @close += 1
      end
    end

    puts "Eww.. scout got stuck"
    nil
  end

  def nearest_unknown(map, unit)
    closest (@map.offset+vec(unit.x, unit.y)), @map.width do |v|
      t = map.at(v.x,v.y)
      if t && t.status == :known && !t.blocked
        map.neighbors_of(v).any? do |nv| 
          nt = map.at(nv.x, nv.y)
          nt && nt.status == :unknown
        end
      else
        false
      end
    end
  end

  def closest(start,max_r=5,&block)
    r = 0
    x = start.x
    y = start.y

    v = vec(x,y)
    match = block.call(v)
    return v if match

    while r < max_r && !match
      r += 1
      rr = 2 * r + 1
      [0,rr-1].each do |i|
        rr.times do |j|
          xx = x + i - r
          yy = y + j - r
          v = vec(xx, yy)
          match = block.call(v)
          return v if match
        end
      end

      (rr-2).times do |i|
        [0,rr-1].each do |j|
          xx = x + i + 1 - r
          yy = y + j - r
          v = vec(x,y)
          match = block.call(v)
          return v if match
        end
      end
    end

    nil
  end

end


class Explore < Strategy
  def has_command?
    @unit.status == 'idle'
  end
  def command
    @dir ||= Game::DIR_VECS.keys.sample
    @num_steps ||= 0
    if (@last_x == @unit.x && @last_y == @unit.y) || @num_steps > 6
      # bumped or went far enough
      @dir = (Game::DIR_VECS.keys-[@dir]).sample
      @num_steps = 0
    end
    @num_steps += 1
    @last_x = @unit.x
    @last_y = @unit.y
    move_command(@unit, @dir)
  end

end

class FrontierPatrol < Strategy
  def has_command?
    @unit.status == 'idle'
  end
  def command
    # TODO nice way to get enemies (eg enemy base)
    target = best_bang_for_buck(@map, @unit)
    if @unit.can_attack && target
      attack_command(@unit, target) if target
    else
      base = @map.enemy_base
      if base
        move_command(@unit, dir_toward_resource(@unit, base))
      else
        resource_tiles = []
        @map.each_resource do |r|
          resource_tiles << r
        end
        farthest = resource_tiles.sort_by do |t|
          dx = (t.x).abs
          dy = (t.y).abs
          dx + dy
        end.last
        @resource = farthest
        move_command(@unit, dir_toward_resource(@unit, @resource)) if @resource
      end
    end
  end

  def best_bang_for_buck(map, u)
    r = u.type == 'tank' ? 2 : 1
    x = u.x
    y = u.y
    targets = []
    ((x-r)..(x+r)).each do |tx|
      ((y-r)..(y+r)).each do |ty|
        next if u.type == 'tank' && (tx == x && ty == y) # don't shoot self

        t = map.trans_at(tx,ty)
        next unless t

        non_dead = t.units.select{|u|u['status'] != 'dead'}.size 
        if non_dead > 0
          # TODO look up if we have units on this spot
          targets << [non_dead, t]
        end

      end
    end

    target = targets.sort_by{|t|t[0]}.last
    target ? target[1] : nil
  end
end

class ExploreBetter < Strategy
  CLOCKWISE_DIR = {
    'N' => 'E',
    'E' => 'S',
    'S' => 'W',
    'W' => 'N'
  }
  COUNTER_CLOCKWISE_DIR = CLOCKWISE_DIR.invert
  def has_command?
    @unit.status == 'idle'
  end
  def command
    @dir ||= Game::DIR_VECS.keys.sample
    @visited ||= Set.new

    # 1 continue in direction until we hit something
    # 2 turn clockwise
    # 3 continue in direction until we can turn left or hit something or we've been here before
    #  if been here, goto 1
    unit_pos = vec(@unit.x, @unit.y)
    stuck = @last_x == @unit.x && @last_y == @unit.y
    been_here = @visited.include?(unit_pos)
    cmd = if !been_here && !@bumped && can_move?(@map, @unit, @dir)
      move_command(@unit, @dir)
    elsif (!been_here && can_move?(@map, @unit, CLOCKWISE_DIR[@dir])) || stuck
      @bumped = true
      @dir = CLOCKWISE_DIR[@dir]
      move_command(@unit, @dir)
    elsif !stuck && been_here
      @bumped = false
      @dir = Game::DIR_VECS.keys.sample
      move_command(@unit, @dir)
    else
      move_command(@unit, @dir)
    end
    
    @last_x = @unit.x
    @last_y = @unit.y
    @visited << unit_pos
    cmd
  end

  private
  def can_move?(map, u, dir)
    v = vec(u.x, u.y) + Game::DIR_VECS[dir]
    t = map.at(v.x, v.y)
    t && !t.blocked
  end

end
