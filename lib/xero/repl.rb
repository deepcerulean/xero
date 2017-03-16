require 'readline'
require 'pastel'

module Xero
  class ReplCommand; end

  class Repl
    def initialize
      @environment = Environment.new
      @processor   = Processor.new(environment: @environment)
      @evaluator   = Evaluator.new
    end

    def launch!
      puts welcome_message
      puts
      debug "Tip: try .help to view the manual."
      puts
      while input = Readline.readline(prompt, true)
        handle(input)
      end
    end

    protected

    def handle(input)
      return if input.empty?
      if input.start_with?('.')
        case input
        when '.show' then
          arrows = @environment.arrows.map { |arrow| "#{arrow.from}-#{arrow.to}" }.join(' ')
          shell_cmd = "undirender #{arrows}"
          puts
          puts pastel.cyan(`#{shell_cmd}`)
        when '.list' then
          puts
          @environment.arrows.each { |arrow| puts "  " + pastel.cyan(arrow) }
          puts
        when '.reset' then
          puts
          @environment.clear!
          puts
        when '.help' then
          puts
          puts help_message
          puts
        else
          err("Unknown repl command #{input}")
        end
      else
        begin
          command = @evaluator.determine(input)
          result  = @processor.execute(command)
          message = result.message
          if result.successful?
            okay(message)
          else
            err(message)
          end
          puts
        rescue => ex
          err(ex.message)
          debug(ex.backtrace)
        end
        puts
      end
    end

    private
    def okay(msg)
      puts "  " + pastel.green(msg)
    end

    def info(msg)
      puts "  " + pastel.white(msg)
    end

    def err(msg)
      puts "  " + pastel.red(msg)
    end

    def debug(msg)
      puts pastel.dim(msg)
    end

    def prompt
      pastel.blue('  xero> ')
    end

    def welcome_message
      pastel.white("XERO #{Xero::VERSION}\n" + '-'*30 + "\n\n\n")
    end

    def help_message
      "\n  " +
      "\n  " + pastel.white("WELCOME TO XERO!") +
      "\n  " +
      "\n  " + pastel.cyan("   define arrow       f: a -> b; g: b -> c") +
      "\n  " + pastel.cyan("   compose arrow      g . f") +
      "\n  " +
      "\n  " + pastel.dim("   repl commands") +
      "\n  " + pastel.dim("   -------------") +
      "\n  " +
      "\n  " + pastel.cyan("     .list            print out all arrows") +
      "\n  " + pastel.cyan("     .show            draw out arrow graph") +
      "\n  "
    end

    def pastel
      @pastel ||= ::Pastel.new
    end
  end
end
