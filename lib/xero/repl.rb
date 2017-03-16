require 'readline'
require 'pastel'

module Xero
  class ReplCommand; end

  class Repl
    attr_reader :halted

    def initialize(processor:)
      @processor   = processor
      @halted = true
    end

    def launch!
      @halted = false
      puts welcome_message
      puts
      debug "Tip: try .help to view the manual."
      puts
      while !halted? && input = Readline.readline(prompt, true)
        handle(input)
      end
      @halted = true
    end

    def halted?; !!@halted end
    def halt!; @halted = true end

    protected

    def environment
      @processor.environment
    end

    def handle(input)
      return if input.empty?
      if input.start_with?('.')
        handle_repl_command(input)
      else
        begin
          result  = @processor.evaluate(input)
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

    def handle_repl_command(input)
      case input
      when '.show' then
        if !environment.arrows.any?
          err('no arrows yet')
        else
          arrows = environment.arrows.map { |arrow| "#{arrow.from}-#{arrow.to}" }.join(' ').gsub("'", "`")
          shell_cmd = "undirender #{arrows}"
          puts
          puts pastel.cyan(`#{shell_cmd}`)
        end
      when '.list' then
        if !environment.arrows.any?
          err('no arrows yet')
        else
          puts
          environment.arrows.each { |arrow| puts "  " + pastel.cyan(arrow) }
        end
      when '.reset' then
        puts
        environment.clear!
      when '.help' then
        puts
        puts help_message
      else
        err("Unknown repl command #{input}")
      end
      puts
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
      "\n  " + pastel.cyan("     .reset           drop all arrows") +
      "\n  " + pastel.cyan("     .help            show this message") +
      "\n  "
    end

    def pastel
      @pastel ||= ::Pastel.new
    end
  end
end
