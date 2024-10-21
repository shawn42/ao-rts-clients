require_relative './lib/pathfinder'
class Map
  attr_reader :width, :height, :tiles, :resource_tiles
  def initialize(game_info)
    @game_info = game_info
    @width = game_info.map_width
    @height = game_info.map_height
    @tiles = Array.new(height*2){Array.new(width*2){Tile.new}}
    @resource_tiles = Set.new
  end

  def reserve(x,y,token)
    at(x+@width, y+@height).reserved_for = token
  end

  def release(x,y)
    at(x+@width, y+@height).reserved_for = nil
  end

  def at(x,y)
    return nil if x < 0 || y < 0 || x > @width*2 || y > @height*2
    col = @tiles[x]
    col && col[y]
  end

  def trans_at(x,y)
    at(x+@width, y+@height)
  end

  def offset
    @offset ||= vec(@width,@height)
  end

  def enemy_base
    @enemy_base
  end

  def base_check_tiles
    dirs = [
      vec(-1,-1),
      vec(-1,0),
      vec(-1,1),

      vec(1,-1),
      vec(1,0),
      vec(1,1),

      vec(0,-1),
      vec(0,1),

      vec(0,0),
    ]
    dirs.map do |d|
      trans_at(d.x,d.y)
    end.compact
  end

  def enemies_near_base
    enemies = []
    base_check_tiles.each do |t|
      t.units.select{|u|u['status'] != 'dead'}.each do |u|
        enemies << HashObject.new(u.merge(x:t.x, y:t.y))
      end
    end
    enemies
  end

  def neighbors_of(loc)
    ns = Game::DIR_VECS.values.map do |v| 
      n_loc = loc + v
      at(n_loc.x, n_loc.y) ? n_loc : nil
    end.compact
    ns
  end

  def each_resource(&blk)
    @resource_tiles.each(&blk)
  end

  def each_known(&blk)
    (@width*2).times do |xi|
      (@height*2).times do |yi|
        t = at(xi,yi)
        yield t if t && t.visible
      end
    end
  end

  def each(&blk)
    (@width*2).times do |xi|
      (@height*2).times do |yi|
        t = at(xi,yi)
        yield t, xi, yi if t
      end
    end
  end

  def update(updates)
    any_tiles_updated = false
    (updates.tile_updates || []).each do |tu|
      tile = trans_at(tu.x,tu.y)
      # no tile means it's off the possible map
      next unless tile

      if tu.visible
        resource_was_removed = false
        was_unknown = tile.status == :unknown
        if tu.resources
          @resource_tiles << tile 
        else
          resource_was_removed = @resource_tiles.delete tile
        end
        update_tile_attrs(tile, tu)
        if tile.units.any?{|u|u['type'] == 'base'}
          @enemy_base = tile 
        end

        any_tiles_updated = any_tiles_updated || ((was_unknown && tile.status != :unknown) || resource_was_removed)
      else
        tile.visible = false
      end
    end
    Pathfinder.clear_cache! if any_tiles_updated
  end

  def resources_at(x, y)
    trans_at(x, y)&.resources
  end

  private
  def update_tile_attrs(tile, attrs)
    tile.status = :known
    attrs.each do |k,v|
      tile.send("#{k}=", v)
    end
  end
end

