require 'bundler'
Bundler.require :default, :test

if ENV['CI'] || (defined?(:RUBY_ENGINE) && RUBY_ENGINE != 'rbx')
  require 'coveralls'
  Coveralls.wear! do
    add_filter 'spec'
  end
end

require 'rbzmq'

Dir[File.expand_path('spec/support/**/*.rb')].each {|f| require f}

RSpec.configure do |config|
  config.order = 'random'

  config.around do |example|
    begin
      Timeout.timeout(10) do
        example.call
      end
    rescue
      raise Timeout::Error.new 'Spec exceeded maximum execution time'
    end
  end
end
