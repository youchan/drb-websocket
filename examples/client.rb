require 'drb/websocket'

factory = DRbObject.new_with_uri "ws://127.0.0.1:1234"
DRb.start_service("ws://127.0.0.1:1234/callback")

remote = factory.get

5.times do
  puts remote.test
  sleep 1
end

remote.set_callback do
  puts "got callback"
end
