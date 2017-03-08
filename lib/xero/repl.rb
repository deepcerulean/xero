require 'readline'

module Xero
  class Repl
    def initialize()
      @environment = Environment.new
      @processor = Processor.new(environment: @environment)
    end

    def launch!
      puts welcome_message
      while input = Readline.readline('> ', true)
        command = @evaluator.determine(input)
        p @processor.execute(command)
      end
    end

    protected
    def welcome_message
      "XERO #{Xero::VERSION}\n" + '-'*30
    end
  end
end
