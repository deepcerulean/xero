require 'readline'

module Xero
  class ReplCommand; end

  class Repl
    def initialize()
      @environment = Environment.new
      @processor = Processor.new(environment: @environment)
      @evaluator = Evaluator.new
    end

    def launch!
      puts welcome_message
      while input = Readline.readline('> ', true)
        begin
          command = @evaluator.determine(input)
          result = @processor.execute(command)
          puts result.message
        rescue => ex
          puts "Error: #{ex.message}"
          puts "[backtrace: #{ex.backtrace}]"
        end
        # puts "objects: #{@environment.objects}"
        # puts "arrows: #{@environment.arrows}
        # puts "dictionary: #{@environment.dictionary}"
      end
    end

    protected

    def welcome_message
      "XERO #{Xero::VERSION}\n" + '-'*30
    end
  end
end
