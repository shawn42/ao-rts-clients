# playground

resources = [
  {value: 10, total: 100, round_trip_path_distance: 4},
  {value: 20, total: 200, round_trip_path_distance: 8},
  {value: 20, total: 200, round_trip_path_distance: 14},
  {value: 20, total: 200, round_trip_path_distance: 14},
  {value: 10, total: 100, round_trip_path_distance: 12},
  {value: 20, total: 200, round_trip_path_distance: 20},
  {value: 20, total: 200, round_trip_path_distance: 4},
]

turns_left = 5*60*5
turns_per_move = 5
starting_workers = 2
build_worker_turns = 5

(1..25).each do |num_workers|
  turns_taken = resources.inject(0) do |sum,r| 
    sum += (r[:total] / r[:value]) * r[:round_trip_path_distance] * turns_per_move / num_workers
  end

  workers_to_build = (num_workers-starting_workers)
  workers_to_build.times do |i|
    turns_taken += ((i+1) * build_worker_turns)
  end
  puts "#{num_workers} workers takes #{turns_taken} / #{turns_left}"
end


# Tier 1
  # perfect collection
# Tier 2
  # can disrupt T1 strats