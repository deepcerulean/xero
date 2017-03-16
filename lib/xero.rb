require 'xero/version'
require 'xero/tokenizer'
require 'xero/parser'
require 'xero/commands'
require 'pry'

module Xero
  ## command interpreter..
  class Interpreter
    include Commands
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
        when DrawChainedCompositionCommand then
          DrawNamedCompositionChainCommand.new(name: name, arrows: arrow_cmd.arrows)
          # DrawNamedArrowCommand.new(name: name, source: arrow_cmd.arrows.first.source, target: arrow_cmd.arrows.last.target)
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
        raise "First element of a composition must be a label" unless ast.left.is_a?(LabelNode)
        if ast.right.is_a?(LabelNode)
        #? [ast.left.value] : analyze(ast.left).arrows
        # right_arrows = ast.right.is_a?(LabelNode) ? [ast.right.value] : analyze(ast.right).arrows
          ComposeArrowsCommand.new(source: ast.left.value, target: ast.right.value) # left_arrows + right_arrows)
        else
          right_cmd = analyze(ast.right)
          case right_cmd
          when ComposeArrowsCommand then # meld with this one composition, linking three arrows
            DrawChainedCompositionCommand.new(arrows: [ast.left.value, right_cmd.source, right_cmd.target])
          when DrawChainedCompositionCommand then # meld with arrows arr
            DrawChainedCompositionCommand.new(arrows: [ast.left.value] + right_cmd.arrows)
          end
        end
      else
        raise "unknown operation type #{ast.value} (expecting :defn or :arrow): #{ast}"
      end
    end
  end

  # wrap tokenize-parse-interpret into one component
  class Evaluator
    def initialize
      @tokenizer = Tokenizer.new
      @parser = Parser.new
      @interpreter = Interpreter.new
    end

    def determine(string)
      tokens = @tokenizer.analyze(string)
      ast = @parser.analyze(tokens)
      command = @interpreter.analyze(ast)
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
    include Commands
    def initialize(env)
      @env = env
    end

    def query_entity(name:)
      if (matching_obj=@env.objects.detect { |obj| obj == name })
        referencing_arrows = @env.arrows.select do |arrow|
          arrow.from == matching_obj || arrow.to == matching_obj
        end
        described_references = referencing_arrows.map(&:to_s).join('; ')
        ok("object #{matching_obj}, referenced by #{described_references}")
      elsif (matching_arrow=@env.arrows.detect { |a| a.name == name })
        ok("arrow #{matching_arrow}")
      else
        err("no entity exists called '#{name}'")
      end
    end

    def compose_arrows(f,g)
      first_arrow = @env.arrows.detect { |arrow| arrow.name == g }
      next_arrow  = @env.arrows.detect { |arrow| arrow.name == f }
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

    def draw_chained_composition(arrows:)
      composition_results = arrows.each_cons(2).map do |l,r|
        compose_arrows(r,l)
      end
      results_messages = composition_results.map(&:message).join('; ')
      if composition_results.all?(&:successful?)
        ok(results_messages)
      else
        err("at least one composition was not successful: #{results_messages}")
      end
    end

    def draw_named_composition_chain(name:, arrows:)
      composition_result = draw_chained_composition(arrows: arrows)
      if composition_result.successful?
        first_arrow = @env.arrows.detect { |arrow| arrows.first == arrow.name }
        last_arrow  = @env.arrows.detect { |arrow| arrows.last  == arrow.name }
        arrow_result = draw_named_arrow(name: name, from: last_arrow.from, to: first_arrow.to)
        ok("drew named composition chain #{name}: #{composition_result.message}; #{arrow_result.message}")
      else
        err("could not draw composition chain #{name}, #{composition_result.message}")
      end
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
      when DrawChainedCompositionCommand then
        draw_chained_composition(
          arrows: command.arrows
        )
      when DrawNamedCompositionChainCommand then
        draw_named_composition_chain(
          name: command.name,
          arrows: command.arrows
        )
      else
        raise("Unknown command type, may need to implement a command handler for #{command.class}..")
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

    private
    def ok(msg)
      CommandSuccessful.new(msg)
    end

    def err(msg)
      CommandFailed.new(msg)
    end
  end

  class Processor
    attr_reader :environment
    def initialize(environment:)
      @environment = environment
      @controller = Controller.new(@environment)
      @evaluator  = Evaluator.new
    end

    def evaluate(string)
      cmd = @evaluator.determine(string)
      execute(cmd)
    end

    protected
    def execute(command)
      @controller.handle(command: command)
    end
  end
end
