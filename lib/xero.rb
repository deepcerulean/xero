require 'xero/version'

module Xero
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

  class Tokenizer
    def analyze(string)
      scanner = StringScanner.new(string)
      tokens = []
      halted = false
      until scanner.eos? || halted
        any_matched = false
        token_kinds.each do |token_kind|
          matched_token = scanner.scan(token_kind.pattern)
          if matched_token
            tokens << token_kind.new(matched_token)
            any_matched = true
            break
          end
        end
        halted = true if !any_matched
      end
      tokens
    end

    def token_kinds
      [ Label, Arrow, Whitespace, Colon ]
    end
  end

  class ExpressionNode
    attr_reader :value, :left, :right
    def initialize(value, left: nil, right: nil)
      @value = value
      @left = left
      @right = right
    end
  end

  class LabelNode < ExpressionNode; end
  class OperationNode < ExpressionNode; end

  class Parser
    # build ast and return root!
    def analyze(tokens)
      tokens.reject! { |token| token.is_a?(Whitespace) }
      expression(tokens)
    end

    protected
    def expression(tokens)
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
        OperationNode.new(operator(second), left: label(first), right: expression(rest))
      end
    end
  end

  class Command; end
  class CreateNamedObjectCommand < Command; end
  class CreateDefinitionCommand < Command
    attr_reader :term, :definition
    def initialize(term:, definition:)
      @term = term
      @definition = definition
    end
  end

  class ComposeElementsCommand < Command
    attr_reader :left, :right
    def initialize(left:, right:)
      @left = left
      @right = right
    end
  end

  class Interpreter
    def analyze(ast)
      if ast.is_a?(OperationNode)
        case ast.value
        when :defn then
          # left = analyze(ast.left)
          raise "Definition name #{label} is not a label" unless ast.left.is_a?(LabelNode)
          CreateDefinitionCommand.new(term: ast.left.value, definition: analyze(ast.right))
        when :arrow then
          # nav thru tree...?
          ComposeElementsCommand.new(left: ast.left.value, right: ast.right.value)
        end
      else
        raise "unknown root node type #{ast.class} (need OperatorNode): #{ast}"
      end
    end
  end

  #####

  class CommandResult; end
  class CommandSuccessful < CommandResult
  end
  class CommandFailed < CommandResult
    def initialize(errors)
      @errors = errors
    end
  end

  class SimpleEnvironment
  end

  class SimpleController
    def initialize(env)
      @env = env
    end

    def create_named_object(name:)
    end

    def compose_elements(left:, right:)
    end

    def create_definition(term:, definition:)
       CommandFailed.new("something bad")
    end
  end

  class Processor
    def initialize(environment:, controlled_by: SimpleController)
      @controller = controlled_by.new(environment)
    end

    def handle(command)
      case command
      when CreateDefinitionCommand then
        @controller.create_definition(
          term: command.term,
          definition: command.definition
        )
      when ComposeElementsCommand then
        @controller.compose_elements(
          left: command.left,
          right: command.right
        )
      else
        CommandFailed.new(["Unknown command type", "please implement a command handler", command])
      end
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
