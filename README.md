# RbZMQ

[![Gem Version](https://badge.fury.io/rb/rbzmq.svg)](http://badge.fury.io/rb/rbzmq)
[![Build Status](http://img.shields.io/travis/jgraichen/rbzmq/master.svg)](https://travis-ci.org/jgraichen/rbzmq)
[![Coverage Status](http://img.shields.io/coveralls/jgraichen/rbzmq/master.svg)](https://coveralls.io/r/jgraichen/rbzmq)
[![Code Climate](http://img.shields.io/codeclimate/github/jgraichen/rbzmq.svg)](https://codeclimate.com/github/jgraichen/rbzmq)
[![Dependency Status](http://img.shields.io/gemnasium/jgraichen/rbzmq.svg)](https://gemnasium.com/jgraichen/rbzmq)
[![RubyDoc Documentation](http://img.shields.io/badge/rubydoc-here-blue.svg)](http://rubydoc.info/github/jgraichen/rbzmq/master/frames)

An opinionated ruby library wrapping [ffi-rzmq](https://github.com/chuckremes/ffi-rzmq) for more rubish flair.

*Library is still pre-release `0.x`. Everything may change anytime.*

## Installation

Add this line to your application's Gemfile:

    gem 'rbzmq', '~> 0.1'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rbzmq

## Usage

You can use RbZMQ's sockets just like in the [zguide](http://zguide.zeromq.org/) but without the need to handle a context. A global context will be used automagically.

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

See `examples/` for a growing number of translated examples from the zguide.

## TODO

* RbZMQ::Reactor
* Pimp RbZMQ::Message
* Socket option accessors
* Class documentation w/ examples
* Translate zguide examples (and try to use them for auto testing)
* Integration options into EventMachine (plus Fibers) / Celluloid (if possible)

## Contributing

1. Fork it (http://github.com/jgraichen/rbzmq/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Copyright (C) 2014 Jan Graichen

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
