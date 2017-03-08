require 'xero/version'
require 'pry'

module Xero
  class Token
    attr_reader :content
    def initialize(val)
      @content = val
    end

    def to_s
      "#{self.class.name}[#@content]"
    end
    alias :inspect :to_s
  end

  class WhitespaceToken < Token
    def self.pattern
      /\s+/
    end
  end

  class LabelToken < Token
    def self.pattern
      /[a-zA-Z]+/
    end
  end

  class OpToken < Token; end

  class ArrowToken < OpToken
    def self.pattern
      /->/
    end
  end

  class ColonToken < OpToken
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
      [ LabelToken, ArrowToken, WhitespaceToken, ColonToken ]
    end
  end

  class ExpressionNode
    attr_reader :value, :left, :right
    def initialize(value, left: nil, right: nil)
      @value = value
      @left = left
      @right = right
    end

    def to_s(depth: 1)
      tabs = "\n" + ('  ' * depth)
      if !(@left || @right)
        tabs + "#{self.class.name}[#@value]"
      else
        tabs + "#{self.class.name}[#@value]\n" +
          tabs + "left: #{@left.to_s(depth: depth+1)}\n" +
          tabs + "right: #{@right.to_s(depth: depth+1)}\n"
      end
    end
    alias :inspect :to_s

  end

  class LabelNode < ExpressionNode; end
  class OperationNode < ExpressionNode; end

  class Parser
    # build ast and return root!
    def analyze(tokens)
      tokens.reject! { |token| token.is_a?(WhitespaceToken) }
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
      if token.is_a?(LabelToken)
        LabelNode.new(token.content)
      end
    end

    def operator(token)
      if token.is_a?(OpToken)
        case token
        when ArrowToken then :arrow
        when ColonToken then :defn
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
  class CreateNamedObjectCommand < Command
    attr_reader :label
    def initialize(label:)
      @label = label
    end
  end

  class CreateDefinitionCommand < Command
    attr_reader :term, :definition
    def initialize(term:, definition:)
      @term = term
      @definition = definition
    end
  end

  class ComposeElementsCommand < Command
    attr_reader :elements
    def initialize(elements:)
      @elements = elements
    end
  end

  class Interpreter
    def analyze(ast)
      raise "AST must be an expression node!" unless ast.is_a?(ExpressionNode)
      if ast.is_a?(OperationNode)
        case ast.value
        when :defn then
          # left = analyze(ast.left)
          raise "Definition name #{label} is not a label" unless ast.left.is_a?(LabelNode)
          CreateDefinitionCommand.new(term: ast.left.value, definition: analyze(ast.right))
        when :arrow then
          left_elems = ast.left.is_a?(LabelNode) ? [ast.left.value] : analyze(ast.left).elements
          right_elems = ast.right.is_a?(LabelNode) ? [ast.right.value] : analyze(ast.right).elements
          ComposeElementsCommand.new(elements: left_elems + right_elems)
        else
          raise "unknown operation type #{ast.value} (expecting :defn or :arrow): #{ast}"
        end
      elsif ast.is_a?(LabelNode)
        CreateNamedObjectCommand.new(label: ast.value)
        # raise "unknown root node type #{ast.class} (need OperationNode): #{ast}"
      end
    end
  end

  # wrap tokenize-parse-interpret into one component
  class Evaluator
    def initialize #(env)
      # @env = Environment.new
      @tokenizer = Tokenizer.new
      @parser = Parser.new
      @interpreter = Interpreter.new
      # @processor = Processor.new(environment: @env)
    end

    def determine(string)
      # puts "[xero eval #{string}]"
      tokens = @tokenizer.analyze(string)
      # puts "tokens: #{tokens}"
      ast = @parser.analyze(tokens)
      # puts "ast: #{ast}"
      command = @interpreter.analyze(ast)
      # puts "command: #{command}"
      command
    end
  end

  #####

  class CommandResult; attr_reader :message end
  class CommandSuccessful < CommandResult
    def initialize(message="ok")
      @message = message
    end
    def successful?; true end
  end

  class CommandFailed < CommandResult
    def initialize(message="error")
      @message = message
    end
    def successful?; false end
  end

  class Environment
    def dictionary
      @dict ||= {}
    end

    def arrows
      @arrows ||= {}
    end

    def objects
      @objects ||= []
    end
  end

  class Controller
    def initialize(env)
      @env = env
    end

    def create_named_object(name:)
      if @env.objects.include?(name)
        CommandFailed.new("an obj already exists called '#{name}'")
      else
        @env.objects << name
        CommandSuccessful.new("okay: created named object '#{name}'")
      end
    end

    def compose_elements(elements:)
      elements.each_cons(2) do |a,b|
        create_named_object(name: a) # ..
        create_named_object(name: b)
        @env.arrows[a] ||= []
        # puts "--- composing '#{a}' and '#{b}'..."
        @env.arrows[a] << b
      end
      CommandSuccessful.new("okay: composed #{elements.join(', ')}")
    end

    def create_definition(term:, definition:)
      @env.dictionary[term] = definition
      CommandSuccessful.new("okay: added definition '#{term}'!")
    end
  end

  class Processor
    def initialize(environment:)
      @controller = Controller.new(environment)
    end

    def execute(command)
      case command
      when CreateDefinitionCommand then
        @controller.create_definition(
          term: command.term,
          definition: command.definition
        )
      when ComposeElementsCommand then
        @controller.compose_elements(
          elements: command.elements
        )
      when CreateNamedObjectCommand then
        @controller.create_named_object(name: command.label)
      else
        CommandFailed.new(["Unknown command type", "please implement a command handler", command])
      end
    end
  end

end
