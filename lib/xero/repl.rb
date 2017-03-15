require 'readline'
require 'pastel'

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
      puts
      puts
      while input = Readline.readline(pastel.blue('> '), true)
        begin
          command = @evaluator.determine(input)
          result = @processor.execute(command)
          message = result.message.capitalize
          if result.successful?
            puts pastel.green(message)
          else
            puts pastel.red(message)
          end
          puts
        rescue => ex
          puts pastel.red("Error: #{ex.message}")
          puts "[backtrace: #{ex.backtrace}]"
        end
        puts
        # puts "objects: #{@environment.objects}"
        # puts "arrows: #{@environment.arrows}
        # puts "dictionary: #{@environment.dictionary}"
      end
    end

    protected

    def welcome_message
      pastel.white("XERO #{Xero::VERSION}\n" + '-'*30)
    end

    def pastel
      @pastel ||= ::Pastel.new
    end
  end
end
