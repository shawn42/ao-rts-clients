require 'rspec'

require_relative './assassin'

describe "Pathfinder#path" do
  before do
    Pathfinder.clear_cache!
  end
  it 'find empty path' do
    game_info = HashObject.new(width: 10, height: 10)
    map = Map.new(game_info)
    path = Pathfinder.path(:units, map, vec(0,0), vec(0,0))
    expect(path).to eq([])
  end

  it 'ends if there is no path' do
    game_info = HashObject.new(width: 10, height: 10)
    map = Map.new(game_info)
    path = Pathfinder.path(:units, map, vec(0,0), vec(1,1))
    expect(path).to eq(nil)
  end

  it 'basic path found' do
    game_info = HashObject.new(width: 10, height: 10)
    map = Map.new(game_info)
    9.times do |i|
      map.trans_at(0,i).status = :known
      map.trans_at(0,i).blocked = false
    end
    path = Pathfinder.path(:units, map, vec(0,0), vec(0,8))
    expect(path).to eq(["S"]*7)
  end

  it 'longer path timing' do
    game_info = HashObject.new(width: 32, height: 32)
    map = Map.new(game_info)
    map.each do |t,x,y|
      t.status = :known
      if x == 48 && y < 60
        t.blocked = true
      end
    end
    # Printer.print(map, {})
    path = Pathfinder.path(:units, map, vec(0,0), vec(31,0), close_enough: 0, max_steps: 64*64)
    expect(path.size).to eq(28+27+32)
  end
end
