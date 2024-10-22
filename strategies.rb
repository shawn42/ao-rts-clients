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
  def commands
    [command]
  end
  def command
    # NO OP
  end
  def update(*args)
  end

  def move_random
    u_vec = vec(@unit.x, @unit.y)
    dir = Game::DIR_VECS.keys.shuffle.find do |d|
      dir_v = Game::DIR_VECS[d]
      new_loc = u_vec + dir_v
      t = @map.trans_at(new_loc.x, new_loc.y)
      t && !t.blocked
    end
    move_command(@unit, dir[0]) if dir
  end

  def dir_toward_resource(u, r)
    dir = dir_toward(u, r.x,r.y, token: u.token)
    if dir == nil
      dir = Pathfinder.dir_toward(vec(u.x,u.y), vec(r.x,r.y)) if resource_adjacent?(u, r)
    end

    dir
  end

  def dir_toward_enemy_base(u, b)
    dir_toward(u, b.x,b.y)
  end

  def dir_toward_base(u)
    dir_toward(u, 0,0)#, close_enough: 0) only needed if we have to walk under the base
  end

  def dir_toward(u, x,y, close_enough: 1)
    token = u.token
    if @path.nil? || @path.empty?
      @path = Pathfinder.path(@units, @map, vec(u.x,u.y), vec(x,y), close_enough: close_enough, reservation_token: token) || []
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
    return if dir.nil?
    {
      command: "GATHER",
      unit: u.id,
      dir: dir,
    }
  end
  def drop_command(u, dir, value)
    return if dir.nil?
    {
      command: "DROP",
      unit: u.id,
      dir: dir,
      value: value
    }
  end
  def move_command(u, dir)
    return if dir.nil?
    {
      command: "MOVE",
      unit: u.id,
      dir: dir,
    }
  end
  def attack_command(u,tile)
    return if tile.nil?
    {
      command: "SHOOT",
      unit: u.id,
      dx: tile.x-u.x,
      dy: tile.y-u.y,
    }
  end
  def melee_command(u,target)
    {
      command: "MELEE",
      unit: u.id,
      target: target['id'],
    }
  end
  def identify_command(u,name)
    {
      command: "IDENTIFY",
      unit: u.id,
      name: name
    }
  end
  def create_command(type)
    {
      command: "CREATE",
      type: type,
    }
  end
end

class CompositeStrategy < Strategy
  def initialize(strat_map)
    @strat_map = strat_map
  end
  def has_command?
    @strat_map.values.any?{|strat|strat.has_command?}
  end
  def update(*args)
    @strat_map.values.each{|strat|strat.update(*args)}
  end

  def commands
    @strat_map.keys.sort.each do |priority|
      strat = @strat_map[priority]
      if strat.has_command?
        return strat.commands
      end
    end
  end
end

class Noop < Strategy
end

class BuildIfYouCan < Strategy
  def initialize(type, *args)
    @type = type
    super(*args)
  end
  def has_command?
    @unit.status == 'idle' && @unit.resource > Game::COSTS[@type]
  end
  def command
    create_command(@type)
  end
end
class RunAwayScared < Strategy
  def has_command?
    @unit.status == 'idle' && (!@enemies.empty? || @path)
  end

  def update(*args)
    @enemies = enemies(@map, @unit)
  end

  # TODO move to parent class
  def enemies(map, u)
    r = u.type == 'scout' ? 5 : 2
    x = u.x
    y = u.y
    baddies = []
    ((x-r)..(x+r)).each do |tx|
      ((y-r)..(y+r)).each do |ty|
        t = map.trans_at(tx,ty)
        next unless t

        non_dead = t.units.select{|u|u['status'] != 'dead'}.map{|e|[HashObject.new(e), vec(tx,ty)]}
        baddies.concat(non_dead)
      end
    end

    baddies
  end

  def command
    dir = nil
    if @path && !@path.empty?
      dir = @path.pop
    else
      @path = nil
      avg_rel_enemy_loc = vec(0,0)
      @enemies.each do |(e,e_pos)|
        avg_rel_enemy_loc += vec(e_pos.x - @unit.x, e_pos.y - @unit.y)
      end
      if @enemies.size > 0
        puts "FOUND ENEMIES TO RUN FROM!"
        avg_rel_enemy_loc *= (1.0/@enemies.size)
        safe_loc = avg_rel_enemy_loc.unit * 4
        u_vec = vec(@unit.x, @unit.y)
        tv = (u_vec - avg_rel_enemy_loc).round
        dir = dir_toward(@unit, tv.x, tv.y, close_enough: 0)
        puts dir
      end
      # dir_vec = avg_rel_enemy_loc.closest_cardinal
      # dir = Game::VEC_DIRS[dir_vec]
    end
    move_command(@unit, dir) if dir
  end
end

class RunAwayIfHurt < Strategy
  def has_command?
    @unit.status == 'idle' && 
      (@was_just_hurt && !@enemies.empty?) || @path
  end

  def update(*args)
    @enemies = enemies(@map, @unit)
    @was_just_hurt = @previous_health && @previous_health > @unit.health
    puts "[#{@unit.id}] OUCH! #{@enemies.size}" if @was_just_hurt
    @previous_health = @unit.health
  end

  def enemies(map, u)
    r = u.type == 'scout' ? 5 : 2
    x = u.x
    y = u.y
    baddies = []
    ((x-r)..(x+r)).each do |tx|
      ((y-r)..(y+r)).each do |ty|
        t = map.trans_at(tx,ty)
        next unless t

        non_dead = t.units.select{|u|u['status'] != 'dead'}.map{|e|[HashObject.new(e), vec(tx,ty)]}
        baddies.concat(non_dead)
      end
    end

    baddies
  end

  def command
    dir = nil
    if @path && !@path.empty?
      dir = @path.pop
    else
      @path = nil
      avg_rel_enemy_loc = vec(0,0)
      @enemies.each do |(e,e_pos)|
        avg_rel_enemy_loc += vec(e_pos.x - @unit.x, e_pos.y - @unit.y)
      end
      if @enemies.size > 0
        puts "FOUND ENEMIES TO RUN FROM!"
        avg_rel_enemy_loc *= (1.0/@enemies.size)
        safe_loc = avg_rel_enemy_loc.unit * 4
        u_vec = vec(@unit.x, @unit.y)
        tv = (u_vec - avg_rel_enemy_loc).round
        dir = dir_toward(@unit, tv.x, tv.y, close_enough: 0)
        puts dir
      end
      # dir_vec = avg_rel_enemy_loc.closest_cardinal
      # dir = Game::VEC_DIRS[dir_vec]
    end
    move_command(@unit, dir) if dir
  end
end

class CollectNearestResource < Strategy
  def has_command?
    @unit.status == 'idle'
  end

  def commands
    [command].tap do |cmds|
      if @resource
        cmds << identify_command(@unit, "#{@resource.x},#{@resource.y}") 
      elsif @turning_in
        cmds << identify_command(@unit, "H") 
      else
        cmds << identify_command(@unit, "?") 
      end
    end
  end

  def command
    new_resource_target = @resource.nil?

    if @unit.resource > 0 && !@turning_in
      @path = nil
      @turning_in = true
    end

    if @unit.resource > 0
      move_command(@unit, dir_toward_base(@unit))
    else
      @turning_in = false
      if @resource && @resource.resources.nil?
        # puts "resource ran out?"
        @unit_manager.unassign_resource(@unit, @res_id)
        @resource = nil 
        @res_id = nil
      end
      @resource ||= self.class.best_resource(@unit, @unit_manager, @map)
      @res_id = @resource.resources.id if @resource

      adjacent_res = resource_adjacent(@unit, @resource)
      if @resource && adjacent_res && @resouce != adjacent_res
        # puts "found resource on way to other resource"
        @unit_manager.unassign_resource(@unit, @res_id)
      end

      if adjacent_res
        @resource = adjacent_res
        r = @resource
        u = @unit
        dir_vec = vec(r.x,r.y) - vec(u.x,u.y)
        @resource = nil
        @res_id = nil
        dir = dir_toward_resource(u, r)
        gather_command(@unit, dir) if dir
      elsif @resource
        if new_resource_target 
          @unit_manager.assign_resource(@unit, @res_id)
        end

        dir = dir_toward_resource(@unit, @resource)
        if dir
          move_command(@unit, dir)
        else
          @unit_manager.unassign_resource(@unit, @res_id) if @res_id
          @resource = nil
          puts 'cannot get to resource going rando'
          move_random
        end
      else
        # no resources? .. keep looking
        # explore until resource
        move_random
      end
    end
  end

  def self.best_resource(u, unit_manager, map, res_to_ignore=Set.new)
    b = unit_manager.base
    tiles = []
    map.each_resource do |t|
      r = t.resources
      if !res_to_ignore.include?(r.id) && (r.total / r.value) > unit_manager.resource_assignments(r.id).size
        tiles << t 
      end
    end

    sorted = tiles.sort_by do |t|
      dx = (t.x-u.x).abs
      dy = (t.y-u.y).abs

      base_dx = (t.x-b.x).abs
      base_dy = (t.y-b.y).abs

      total_dist = dx+dy+base_dx+base_dy
      value = t.resources.value
      value.to_f/total_dist 
    end
    # TODO how bad would it be to cache this on the resource?
    sorted = sorted.reverse[0..10].sort_by do |t|
      # u_vec = vec(u.x,u.y)
      t_vec = vec(t.x,t.y)
      b_vec = vec(b.x,b.y)

      # target_path = Pathfinder.path(unit_manager.units, map, u_vec, t_vec)
      base_path = Pathfinder.path(unit_manager.units, map, t_vec, b_vec)
      base_dist = base_path&.size || 9999
      # target_dist = target_path&.size || 9999
      # total_dist = target_dist + base_dist
      total_dist = base_dist*2
      value = t.resources.value
      value.to_f/total_dist
    end
    sorted.last
  end
end


require_relative 'brigade'
class BucketBrigadeCollector < CollectNearestResource
  STATES = [:no_brigade,:moving,:gathering,:dropping]
  attr_accessor :target, :state, :brigade

  # def self.best_resource(u, unit_manager, map, res_to_ignore=Set.new)
  #   return CollectNearestResource.best_resource(u, unit_manager, map, res_to_ignore)
  def self.best_resource(search_u, unit_manager, map, res_to_ignore=Set.new)
    b = unit_manager.base
    tiles = []
    map.each_resource do |t|
      r = t.resources
      if !res_to_ignore.include?(r.id) && (r.total / r.value) > unit_manager.resource_assignments(r.id).size
        tiles << t 
      end
    end

    sorted = tiles.sort_by do |t|
      dx = 0#(t.x-search_u.x).abs
      dy = 0#(t.y-search_u.y).abs

      base_dx = (t.x-b.x).abs
      base_dy = (t.y-b.y).abs

      dx+dy+base_dx+base_dy
    end
    # TODO how bad would it be to cache this on the resource?
    # bus = unit_manager.units.values().select { |u| u.type == "worker" && u.token == search_u.token }.dup
    # avg_pos = bus.map { |b| vec(b.x, b.y) }.reduce(:+) / bus.size
    sorted = sorted[0..10].sort_by do |t|
      t_vec = vec(t.x,t.y)
      b_vec = vec(b.x,b.y)

      base_path = Pathfinder.path(unit_manager.units, map, t_vec, b_vec, translate_to_moves: false)
      base_path&.size || 99_999
      # if base_path.nil? || base_path.empty?
      #   99_999
      # else
      #   # puts "Base path: #{base_path.inspect}"
      #   path_avg = (base_path.map { |p| vec(p.x, p.y) }.reduce(:+) || 99_999) / (base_path.size || 1)

      #   dx = (avg_pos.x-path_avg.x).abs
      #   dy = (avg_pos.y-path_avg.y).abs
      #   dx+dy
      # end
    end
    # sorted.last
    sorted.first
  end

  def commands
    @state ||= :no_brigade

    # TODO: move this somewhere not dumb
    @unit_manager.clear_finished_brigades!

    claimed_resources = []
    @unit_manager.brigades.each do |b|
      if b.resource&.is_a?(Tile)
        claimed_resources << b.resource.resources.id if b.resource.resources
      end
      b.path.each do |p_loc|
        res = @map.resources_at(p_loc.x, p_loc.y)
        if res
          claimed_resources << res.id
        end
      end
    end

    resource = self.class.best_resource(@unit, @unit_manager, @map, claimed_resources)
    return nil unless resource


    # only allow 2 brigades for now
    allowed_brigade_size = 3
    if @state == :no_brigade && @unit_manager.brigades.size >= allowed_brigade_size &&
      @unit_manager.brigades.select(&:needs_help?).empty?
      return nil
    end


    command = nil
    case @state
    when :no_brigade
      partial_brigade = @unit_manager.brigades.select(&:needs_help?).first
      if partial_brigade
        partial_brigade.add_unit(@unit)
        @brigade = partial_brigade
        @target = partial_brigade.position_for(@unit)
        @state = :moving
        # puts "JOINING BRIGADE #{partial_brigade.reservation_token}, U:#{@unit.id}, T:#{@target.x},#{@target.y}"
      else
        resource = self.class.best_resource(@unit, @unit_manager, @map, claimed_resources)
        if resource
          begin
            @brigade = Brigade.new(resource, @map, @unit_manager)
            @unit_manager.brigades << @brigade
            return commands
          rescue Exception => e
            puts "Error creating brigade: #{e.message}"
            # keep waiting for a path to open up
            @state = :no_brigade
          end
        else
          puts "RANDO BUCKETS"
          command = nil#move_random
        end
      end
    when :moving
      u_vec = vec(@unit.x, @unit.y)
      if u_vec == @target 
        if @brigade.nil? || @brigade.done?
          @state = :no_brigade
        else
          @brigade.progress!
          @state = :gathering
        end
      else
        @brigade&.progress!
        dir = dir_toward(@unit, @target.x, @target.y, close_enough: 0)
        command = move_command(@unit, dir)
      end
    when :gathering
      dir = @brigade.dir_to_gather(@unit)
      gather_loc = @brigade.gather_loc(@unit)
      if @map.resources_at(gather_loc.x, gather_loc.y)
        @brigade.progress!
        command = gather_command(@unit, dir)
        @state = :dropping
      elsif @brigade.unit_done?(@unit)
        if @brigade.reassign(@unit)
          @target = @brigade.position_for(@unit)
          @state = :moving
        else
          @unit.token = nil
          @brigade = nil
          @state = :no_brigade
        end
      end
    when :dropping
      dir = @brigade.dir_to_drop(@unit)
      if dir
        @brigade.progress!
        command = drop_command(@unit, dir, 20)
      else
        @state = :gathering
      end

      # TODO optimization to release workers early... for now.. evaluate the whole brigade
      if @brigade.done?
        @state = :no_brigade
      else
        @state = :gathering
      end
    else
      # something went wrong
      command = nil
    end

    [command].compact
  end
end


class MoveRandom < Strategy
  def has_command?
    @unit.status == 'idle'
  end
  def command
    move_random
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
      @path ||= Pathfinder.path(@units, @map, u_vec, @target, close_enough: @close)
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

    move_random
  end

  def nearest_unknown(map, unit)
    closest (map.offset+vec(unit.x, unit.y)), map.width do |v|
    # closest map.offset, map.width do |v|
      t = map.at(v.x,v.y)
      if t && t.status == :known && !t.blocked
        map.neighbors_of(v).any? do |nv| 
          nt = map.at(nv.x, nv.y)
          nt && nt.status == :unknown && Pathfinder.path(@units, @map, vec(t.x, t.y), vec(unit.x, unit.y))
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

class DefendBase < Strategy
  def has_command?
    @enemies = @map.enemies_near_base
    should_defend = @unit.x.abs < 10 && @unit.y.abs < 10 && @enemies.size > 0
    # puts "DEFEND THE BASE!! #{Time.now.to_i}" if should_defend
    should_defend
  end

  def commands
    [command].tap do |cmds|
      cmds << identify_command(@unit, "!") 
    end
  end

  def command
    target = @enemies.first
    range = @unit.type == 'tank' ? 2 : 1
    dist = (vec(target.x,target.y) - vec(@unit.x,@unit.y)).magnitude
    if @unit.can_attack && dist <= range
      @unit.type == 'tank' ? attack_command(@unit, vec(target.x,target.y)) : melee_command(@unit, target)
    else
      move_command(@unit, dir_toward(@unit, target.x, target.y, close_enough: range))
    end
  end
end

class KillBase < Strategy
  def has_command?
    @unit.status == 'idle' && @map.enemy_base # || @map.enemy_next_to(@unit)
  end

  def command
    base = @map.enemy_base
    target = best_bang_for_buck(@map, @unit)

    if @unit.can_attack && target
      @unit.type == 'tank' ? attack_command(@unit, target) : melee_command(@unit, target)
    else
      if base
        move_command(@unit, dir_toward_enemy_base(@unit, base))
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
        # next if u.type == 'tank' && (tx == x && ty == y) # don't shoot self

        t = map.trans_at(tx,ty)
        next unless t

        non_dead = t.units.select{|u|u['status'] != 'dead'}
        if non_dead.size > 0
          # TODO look up if we have units on this spot
          score = non_dead.size # TODO: balance with own loss of life
          targets << [score, t, non_dead.first]
        end

      end
    end

    target = targets.sort_by{|t|t[0]}.last
    return nil if target.nil?
    u.type == 'tank' ? target[1] : target[2]
  end
end

class ProtectBase < KillBase
  def command
    base = @map.enemy_base
    target = best_bang_for_buck(@map, @unit)

    if @unit.can_attack && target
      @unit.type == 'tank' ? attack_command(@unit, target) : melee_command(@unit, target)
    end
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
