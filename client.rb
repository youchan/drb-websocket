require 'drb/websocket'

factory = DRbObject.new_with_uri "ws://127.0.0.1:1234"

remote = factory.get
puts remote.test
