class Brigade
  attr_accessor :resource, :path, :units
  def initialize(resource, map, base)
    @resource = resource
    @units = []
    @map = map
    b_vec = vec(base.x, base.y)
    t_vec = vec(resource.x, resource.y)
    @path = Pathfinder.path(nil, @map, b_vec, t_vec, 1, 10_000, false).reverse
    # NOTE if the path is even length; unit will need to stand on the base
    @path << vec(0,0) if @path.size.even?
    puts "building brigade: for #{@resource.resources} with #{@path} and #{@units.map(&:id)}"
  end

  def trim!
    # TODO 
    # look on our path and map to figure out where the farthest resource on the path is
  end

  def unit_done?(unit)
    if unit == @units.first
      @resource.nil? || @resource.resources.nil? || @resource.resources.total <= 0
    else
      n = @units.index(unit)

      target_loc = @path[spot_for_nth_worker(n)-1]
      res = nil
      # ewww.. linear walk through...
      @map.each_resource do |t|
        if t.x == target_loc.x && t.y == target_loc.y
          res = t
        end
      end

      unit_done?(@units[n-1]) && (res.nil? || res.resources.total <= 0)
    end
  end

  def dir_to_gather(unit)
    pos_in_line = @units.index(unit)
    i = spot_for_nth_worker(pos_in_line)-1
    target = unit == @units.first ? vec(@resource.x, @resource.y) : @path[i % @path.size]
    Pathfinder.dir_toward(unit, target)
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
    @path.nil? || (@path.size / 2 + 1) > @units.size
  end

  private
  def spot_for_nth_worker(n)
    n*2
  end
end