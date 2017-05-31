class Printer
  UNIT_MARKERS = {
    'base' => 'B',
    'worker' => 'w',
    'scout' => 's',
    'tank' => 't',
  }
  def self.print(map, units)
    return if $quiet
    unit_lookup = Hash.new { |hash, key| hash[key] = {} }
    units.values.each do |u|
      ux = u.x+map.width
      uy = u.y+map.height
      col = unit_lookup[ux]
      col[uy] = u
    end
    20.times do puts end

    (map.height*2).times do |y|
      STDOUT.write "|"
      (map.width*2).times do |x|
        v = map.at(x,y)
        if v.nil? || (v && v.status == :unknown)
          STDOUT.write "?"
        elsif v.resources
          STDOUT.write "$"
        elsif v.blocked
          STDOUT.write "X"
        elsif !v.visible
          STDOUT.write "."
        else
          if u = unit_lookup[x][y]
            STDOUT.write UNIT_MARKERS[u.type]
          else
            STDOUT.write " "
          end
        end
      end
      STDOUT.puts "|"
    end
    puts("="*66)
  end
end
