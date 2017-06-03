require 'drb/websocket'

remote = DRbObject.new_with_uri "ws://127.0.0.1:1234"

puts remote.test
