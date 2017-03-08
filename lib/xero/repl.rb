require 'readline'

module Xero
  class Repl
    def initialize()
      @environment = Environment.new
      @processor = Processor.new(environment: @environment)
      @evaluator = Evaluator.new
    end

    def launch!
      puts welcome_message
      while input = Readline.readline('> ', true)
        command = @evaluator.determine(input)
        result = @processor.execute(command)
        puts result.message
      end
    end

    protected
    def welcome_message
      "XERO #{Xero::VERSION}\n" + '-'*30
    end
  end
end
