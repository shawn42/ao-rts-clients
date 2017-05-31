desc "Park a tank on the enemy base!"
task :assassin, [:port] do |t, args|
  port = args[:port] || 9090
  sh "ruby runner.rb assassin #{port}"
end

desc "RUSH!"
task :zerg, [:port] do |t, args|
  port = args[:port] || 9090
  sh "ruby runner.rb zerg #{port}"
end

desc "Collect with 1 scout"
task :collect, [:port] do |t, args|
  port = args[:port] || 9090
  sh "ruby runner.rb collect #{port}"
end

task default: "assassing[9090]"
