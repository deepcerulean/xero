require 'xero/version'
require 'xero/tokenizer'
require 'xero/parser'
require 'pry'

module Xero
  ## command interpreter..
  class Command; end
  class QueryEntityCommand < Command
    attr_reader :name
    def initialize(name:)
      @name = name
    end
  end

  class DrawArrowCommand < Command
    attr_reader :source, :target
    def initialize(source:, target:)
      @source = source
      @target = target
    end
  end

  class ComposeArrowsCommand < Command
    attr_reader :source, :target
    def initialize(source:, target:)
      @source = source
      @target = target
    end
  end

  class DrawNamedArrowCommand < Command
    attr_reader :name, :source, :target
    def initialize(name:, source:, target:)
      @name = name
      @source = source
      @target = target
    end
  end

  # this is effectively the same as draw named arrow
  # but needs the env to de-ref the arrow defns
  class DrawNamedCompositionCommand < Command
    attr_reader :name, :first_arrow, :second_arrow
    def initialize(name:, first_arrow:, second_arrow:)
      @name = name
      @first_arrow = first_arrow
      @second_arrow = second_arrow
    end
  end

  class DrawLinkedArrowsCommand < Command
    attr_reader :objects
    def initialize(objects:)
      @objects = objects
    end
  end

  class CommandList < Command
    attr_reader :subcommands
    def initialize(subcommands:)
      @subcommands = subcommands
    end
  end

  class Interpreter
    def analyze(ast)
      raise "AST must be an ExpressionNode! (was #{ast.class}: #{ast})" unless ast.is_a?(ExpressionNode)
      if ast.is_a?(OperationNode)
        analyze_operation(ast)
      elsif ast.is_a?(StatementListNode)
        CommandList.new(subcommands: ast.statements.map { |stmt| analyze(stmt) })
      elsif ast.is_a?(LabelNode)
        QueryEntityCommand.new(name: ast.value)
      else
        raise "unknown root node type #{ast.class} (need OperationNode or LabelNode): #{ast}"
      end
    end

    def analyze_operation(ast)
      case ast.value
      when :defn then
        raise "Definition name #{label} is not a label" unless ast.left.is_a?(LabelNode)
        name = ast.left.value
        arrow_cmd = analyze(ast.right)
        case arrow_cmd
        when ComposeArrowsCommand then
          DrawNamedCompositionCommand.new(name: name, first_arrow: arrow_cmd.source, second_arrow: arrow_cmd.target)
        when DrawArrowCommand then
          DrawNamedArrowCommand.new(name: name, source: arrow_cmd.source, target: arrow_cmd.target)
        else # TODO linked arrow defs..
          raise "Unknown type of definition (not arrow or composition of arrows): #{arrow_cmd}"
        end
      when :arrow then
        if ast.left.is_a?(LabelNode) && ast.right.is_a?(LabelNode)
          DrawArrowCommand.new(source: ast.left.value, target: ast.right.value)
        else
          if ast.left.is_a?(LabelNode)
            # try to process the right into a series of draw arrow commands...
            right_cmd = analyze(ast.right)
            case right_cmd
            when DrawArrowCommand # meld with this one arrow, linking 3 objs
              DrawLinkedArrowsCommand.new(objects: [ast.left.value, right_cmd.source, right_cmd.target])
            when DrawLinkedArrowsCommand # meld with objs arr
              DrawLinkedArrowsCommand.new(objects: [ast.left.value] + right_cmd.objects)
            else
              raise "Parsed unknown command #{right_cmd} from #{ast.right}"
            end
          else
            raise "for now can only draw arrows starting from a named object..."
          end
        end
      when :dot then
        raise "can only compose two named arrows at once :(" unless ast.left.is_a?(LabelNode) && ast.right.is_a?(LabelNode)
        #? [ast.left.value] : analyze(ast.left).arrows
        # right_arrows = ast.right.is_a?(LabelNode) ? [ast.right.value] : analyze(ast.right).arrows
        ComposeArrowsCommand.new(source: ast.left.value, target: ast.right.value) # left_arrows + right_arrows)
      else
        raise "unknown operation type #{ast.value} (expecting :defn or :arrow): #{ast}"
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

  class Entity
    attr_reader :name
    def initialize(name:)
      @name = name
    end
  end

  class Arrow
    attr_accessor :name
    attr_reader :to, :from
    def initialize(from:, to:, name: nil)
      @from = from
      @to = to
      @name = name
    end

    def compose(other)
      if other.to == self.from
        Arrow.new(from: other.from, to: self.to)
      else
        raise "Can't compose #{other} -> #{self} (non-matching ends)"
      end
    end

    def to_s
      if @name
        "#@name: #@from -> #@to"
      else
        "#@from -> #@to"
      end
    end
    alias :inspect :to_s
  end

  class Environment
    def arrows
      @arrows ||= []
    end

    def objects
      arrows.flat_map { |arrow| [arrow.from, arrow.to] }.uniq
    end

    def clear!
      @arrows = []
    end
  end

  class Controller
    def initialize(env)
      @env = env
    end

    def query_entity(name:)
      if (matching_obj=@env.objects.detect { |obj| obj == name })
        referencing_arrows = @env.arrows.select { |arrow| arrow.from == matching_obj || arrow.to == matching_obj }
        ok("object #{matching_obj}, referenced by #{referencing_arrows.map(&:to_s).join('; ')}")
      elsif (matching_arrow=@env.arrows.detect { |a| a.name == name })
        ok("arrow #{matching_arrow}")
      else
        err("no entity exists called '#{name}'")
      end
    end

    def compose_arrows(f,g)
      first_arrow = @env.arrows.detect { |arrow| arrow.name == g }
      next_arrow  = @env.arrows.detect { |arrow| arrow.name == f }

      # compose them
      composition = first_arrow.compose(next_arrow)
      create_anonymous_arrow(from: composition.from, to: composition.to)
      ok("composed arrows #{first_arrow} and #{next_arrow} yielding #{composition}")
    end

    def draw_arrow(from:,to:)
      create_anonymous_arrow(from: from, to: to)
    end

    def draw_named_arrow(from:, to:, name:)
      create_or_name_arrow(from: from, to: to, name: name)
    end

    def draw_named_composition(first_arrow:, second_arrow:, name:)
      the_first  = @env.arrows.detect { |arrow| arrow.name == first_arrow }
      the_second = @env.arrows.detect { |arrow| arrow.name == second_arrow }
      composition = the_first.compose(the_second)
      create_or_name_arrow(from: composition.from, to: composition.to, name: name)
    end

    def draw_linked_arrows(between:)
      results = []
      between.each_cons(2) do |from,to|
        results << draw_arrow(from: from, to: to)
      end
      ok(results.map(&:message).join('; '))
    end

    def handle_multiple(commands:)
      results = commands.map do |command|
        handle(command: command)
      end
      ok(results.map(&:message).join('; '))
    end

    def handle(command:)
      case command
      when DrawNamedArrowCommand then
        draw_named_arrow(
          from: command.source,
          to: command.target,
          name: command.name
        )
      when DrawNamedCompositionCommand then
        draw_named_composition(
          name: command.name,
          first_arrow: command.first_arrow,
          second_arrow: command.second_arrow
        )
      when DrawArrowCommand then
        draw_arrow(
          from: command.source,
          to: command.target
        )
      when ComposeArrowsCommand then
        compose_arrows(
          command.target,
          command.source
        )
      when QueryEntityCommand then
        query_entity(
          name: command.name
        )
      when DrawLinkedArrowsCommand then
        draw_linked_arrows(
          between: command.objects
        )
      when CommandList then
        handle_multiple(
          commands: command.subcommands
        )
      else
        err(["Unknown command type", "please implement a command handler for #{command.class}", command])
      end
    end

    protected
    def create_anonymous_arrow(to:,from:)
      raise "Arrows can't point to arrows" if @env.arrows.map(&:name).any? { |nm| nm == to || nm == from }
      if @env.arrows.any? { |arrow| arrow.from == from && arrow.to == to }
        err("arrow already exists between #{from} and #{to}")
      else
        @env.arrows << Arrow.new(from: from, to: to)
        ok("created anonymous arrow from #{from} to #{to}")
      end
    end

    def create_or_name_arrow(name:,to:,from:)
      raise "Arrows can't point to arrows" if @env.arrows.map(&:name).any? { |nm| nm == to || nm == from }
      raise "Objects can't also be arrows" if @env.objects.any? { |obj| name == obj }
      puts "--- CREATE (OR ASSIGN NAME TO) ARROW #{name} FROM #{from} TO #{to}"

      if (existing_arrow=@env.arrows.detect { |arrow| arrow.from == from && arrow.to == to })
        if existing_arrow.name.nil?
          raise "Arrow names must be unique" if @env.arrows.any? { |arrow| arrow.name == name }
          # is this a valid name??
          existing_arrow.name = name
          ok("unnamed arrow from #{from} to #{to} was given name #{name}")
        else
          err("named arrow #{name} already exists between #{from} and #{to}")
        end
      else
        raise "Arrow names must be unique" if @env.arrows.any? { |arrow| arrow.name == name }
        @env.arrows << Arrow.new(from: from, to: to, name: name)
        ok("created arrow named #{name} from #{from} to #{to}")
      end
    end

    def ok(msg)
      CommandSuccessful.new(msg)
    end

    def err(msg)
      CommandFailed.new(msg)
    end
  end

  class Processor
    def initialize(environment:)
      @controller = Controller.new(environment)
    end

    def execute(command)
      @controller.handle(command: command)
    end

    def evaluate(string)
      cmd = evaluator.determine(string)
      execute(cmd)
    end

    private
    def evaluator
      @evaluator ||= Evaluator.new
    end
  end
end
