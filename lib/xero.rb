require 'xero/version'

module Xero
  class Environment
  end

  class Token
    attr_reader :content
    def initialize(val)
      @content = val
    end
  end

  class Whitespace < Token
    def self.pattern
      /\s+/
    end
  end

  class Label < Token
    def self.pattern
      /[a-zA-Z]+/
    end
  end

  class OpToken < Token; end

  class Arrow < OpToken
    def self.pattern
      /->/
    end
  end

  class Colon < OpToken
    def self.pattern
      /:/
    end
  end

  # class LeftParens ...

  class Tokenizer
    def analyze(string)
      scanner = StringScanner.new(string)
      tokens = []
      until scanner.eos?
        token_kinds.each do |token_kind|
          matched_token = scanner.scan(token_kind.pattern)
          if matched_token
            tokens << token_kind.new(matched_token)
            break
          end
        end
      end
      tokens #.reject { |token| token.is_a?(Whitespace) }
    end

    def token_kinds
      [ Label, Arrow, Whitespace ]
    end
  end

  class ExpressionNode
    attr_reader :value, :left, :right
    def initialize(value, left: nil, right: nil) #, children: [])
      @value = value
      @left = left
      @right = right
      # @children = children
    end
  end

  class LabelNode < ExpressionNode; end
  class OperatorNode < ExpressionNode; end

  class Parser
    # build ast and return root!
    def analyze(tokens)
      # toss whitespace out
      tokens.reject! { |token| token.is_a?(Whitespace) }
      puts "--- ANALYZE tokens=#{tokens}"
      expression(tokens)
    end

    def expression(tokens)
      # eventually, lists of ops -> defs; key/barewords -> cmds; lists of defs + cmds -> prog
      if tokens.length == 1
        the_token = tokens.first
        return label(the_token) if label(the_token)
      else
        operation(tokens)
      end
    end

    def label(token)
      if token.is_a?(Label)
        LabelNode.new(token.content)
      end
    end

    def operator(token)
      if token.is_a?(OpToken)
        case token
        when Arrow then :arrow
        when Colon then :defn
        end
      end
    end

    def operation(tokens)
      first, second, *rest = tokens
      if label(first) && operator(second) && expression(rest)
        OperatorNode.new(operator(second), left: label(first), right: expression(rest))
      end
    end
  end

  class Command; end
  class HaulCommand < Command; end
  class CommandResult; end
  class SuccessfulCommand < CommandResult; end

  class Interpreter
    def analyze(ast)
      # turn ast into command
    end
  end

  class Processor
    def initialize(environment)
      @env = environment
    end

    def analyze(command)
      # compute result of command in environment
      # aggregate fired events for further processing...
    end
  end

  class Repl
    attr_reader :env
    def initialize
      @env = Environment.new
      @tokenizer = Tokenizer.new
      @parser = Parser.new
      @interpreter = Interpreter.new
      @processor = Processor.new(@env)
    end

    def launch!
      puts welcome_message
      print ">> "
      xero_eval(gets.chomp)
    end

    protected

    def welcome_message
      "XERO #{Xero::VERSION}\n\n\n"
    end

    private

    def xero_eval(command)
      puts "[xero eval #{command}]"
      tokens = @tokenizer.analyze(gets)
      puts "tokens: #{tokens}"
      ast = @parser.analyze(tokens)
      puts "ast: #{ast}"
      command = @interpreter.analyze(ast)
      puts "commands: #{commands}"
      result, events = @processor.analyze(command)
      puts "result: #{result}"
      puts "events: #{events}"
    end
  end
end
