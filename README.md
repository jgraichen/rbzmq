# RbZMQ

An opinionated ruby library wrapping [ffi-rzmq](https://github.com/chuckremes/ffi-rzmq) for more rubish flair.

## Installation

Add this line to your application's Gemfile:

    gem 'rbzmq', '~> 0.1'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rbzmq

## Usage

You can use {RbZMQ::Socket}s just like in the [zguide](http://zguide.zeromq.org/) but without the need to handle a context. A global context will be used automagically.

```ruby
require 'rbzmq'

writer = RbZMQ::Socket.new ZMQ::PUSH
writer.connect 'tcp://127.0.0.1:4237'

writer.send 'My Message!'
writer.send 'My Second Message!'

reader = RbZMQ::Socket.new ZMQ::PULL
reader.bind 'tcp://127.0.0.1:4237'

p reader.recv.to_s
p reader.recv.to_s

writer.close
reader.close
```

## Contributing

1. Fork it ( http://github.com/jgraichen/rbzmq/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
