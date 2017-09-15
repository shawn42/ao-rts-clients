require 'socket'
require 'oj'
require 'set'
require 'thread'
require_relative './base'
require_relative './lib/printer'

if $0 == __FILE__
  strat = ARGV[0]
  require_relative "./clients/#{strat}"
  port = ARGV.size > 1 ? ARGV[1].to_i : 9090
  $quiet = ARGV.size > 2

  if $quiet
    def puts(*args)
    end
  end
  server = TCPServer.new port

    Thread.abort_on_exception = true
  loop do
    Thread.new(server.accept) do |server_connection|
      puts "CONNECTED"

      game = Game.new Object.const_get("#{strat.capitalize}UnitManager")
      msg_from_server = Queue.new

      listening_thread = Thread.new do
        begin
          while msg = server_connection.gets
            msg_from_server.push msg
          end
        end
      end

      begin
        update_count = 0
        
        loop do
          msg = msg_from_server.pop
          msgs = [msg]
          until msg_from_server.empty?
            puts "!!! missed turn!"
            msgs << msg_from_server.pop 
          end

          msgs.each do |msg|
            update_count += 1
            updates = Oj.load(msg)
            update_obj = HashObject.new updates
            if update_obj.game_info
              game.setup(update_obj.game_info)
            end
            game.update(update_obj)
          end

          commands = game.generate_commands

          if update_count % 5 == 0
            # Printer.print(game.map, game.unit_manager.units)
          end
          server_connection.puts(Oj.dump(commands, mode: :compat))
        end

      rescue Exception => ex
        p ex
        p ex.backtrace
        raise ex
      end

      server_connection.close
    end
  end
end
