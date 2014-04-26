require 'bundler'
Bundler.setup :default, :test

if ENV['CI'] || (defined?(:RUBY_ENGINE) && RUBY_ENGINE != 'rbx')
  require 'coveralls'
  Coveralls.wear! do
    add_filter 'spec'
  end
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
    Coveralls::SimpleCov::Formatter,
    SimpleCov::Formatter::HTMLFormatter
  ]
end

require 'rbzmq'

Dir[File.expand_path('spec/support/**/*.rb')].each{|f| require f }

RSpec.configure do |config|
  config.order = 'random'

  config.around do |example|
    err = catch(:err) do
      begin
        Timeout.timeout(30) do
          begin
            example.call
          rescue => e
            throw :err, e
          end
        end
      rescue Timeout::Error
        throw :err, Timeout::Error.new('Spec exceeded maximum execution time')
      end
    end

    raise err if err.is_a?(Exception)
  end
end
