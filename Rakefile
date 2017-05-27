desc "Park a tank on the enemy base!"
task :assassin, [:port] do |t, args|
  port = args[:port] || 9090
  sh "ruby runner.rb assassin #{port}"
end

task default: "assassing[9090]"
