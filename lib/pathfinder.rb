require 'set'
require_relative './vec'

class Pathfinder
  def self.clear_cache!
    # puts "clearing paths! calculated #{@num_paths} / #{@cache_hits} since last clearing"
    @paths = nil
  end

  def self.path(units, map, from, to, close_enough=1, max_steps=1000, translate_to_moves=true)
    @num_paths ||= 0
    @cache_hits ||= 0
    if h(from, to) <= close_enough
      return []
    end
    @paths ||= Hash.new{|h,k| h[k] = {}}
    from = from+map.offset
    to = to+map.offset
    if @paths[from].has_key?(to) && translate_to_moves
      cached_path = @paths[from][to]
      @cache_hits += 1
      return cached_path ? cached_path.clone : nil
    end
    @num_paths += 1
    return nil if @pathing
    # @pathing = true  # make them take turns w/ pathing
    steps = 0
    open = [from]
    closed = Set.new
    parent_map = {}
    price_map = {from => h(from, to)}
    cost_map = {from => 0}
    fast_stack = []

    while !(fast_stack.empty? && open.empty?) && (steps < max_steps)
      loc = fast_stack.shift
      if loc.nil?
        open.sort_by!{|n| price_map[n]}
        loc = open.shift
      end
      gh = price_map[loc]
      steps += 1
      if h(loc, to) <= close_enough
        instructions = build_path(parent_map, loc, translate_to_moves)
        @paths[from][to] = instructions.clone
        @pathing = false
        return instructions
      end

      closed << loc
      map.neighbors_of(loc).each do |n|
        t = map.at(n.x, n.y)
        if t && (t.blocked || t.status == :unknown)
          closed << n 
        end
        unless closed.include?(n)
          cost_map[n] = cost_map[loc] + 1
          n_gh = cost_map[n] + h(n, to)
          old_price = price_map[n]
          if old_price.nil? || old_price > n_gh
            price_map[n] = n_gh 
            parent_map[n] = loc
          end
          if old_price.nil?
            if n_gh <= price_map[loc]
              fast_stack.unshift n
            else
              open.unshift(n) if old_price.nil?
            end
          end
        end
      end
    end
    puts "no more steps" if steps > max_steps
    @paths[from][to] = nil
    @pathing = false
    return nil
  end

  def self.build_path(parents, loc, translate=true)
    path = [loc]
    while loc = parents[loc]
      path << loc
    end
    path = path.reverse
    if translate
      dirs = []
      last_loc = path[0]
      path[1..-1].each do |loc|
        dirs << dir_toward(last_loc, loc)
        last_loc = loc
      end
      dirs
    else
      coords = []
      last_loc = path[0]
      path[1..-1].each do |loc|
        coords << (loc - path[0])
        last_loc = loc
      end
      coords
    end
  end

  def self.h(from, target)
    val = (target.x - from.x).abs + (target.y - from.y).abs
    # puts "H: #{from} #{target} #{val}"
    val
  end

  def self.dir_toward(from, to)
    v = vec(to.x-from.x, to.y-from.y).unit
    Game::VEC_DIRS[vec(v.x.to_i, v.y.to_i)][0]
  end
end