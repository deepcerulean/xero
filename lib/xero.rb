require 'xero/version'
require 'xero/tokenizer'
require 'xero/parser'
require 'xero/commands'
require 'xero/interpreter'
require 'pry'

module Xero
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
        raise "Can't compose #{other} and #{self} (non-matching ends)"
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
      check results
      # ok(results.map(&:message).join('; '))
    end

    def draw_named_arrow_links(name:, objects:)
      link_arrows_result=draw_linked_arrows(between: objects)
      if link_arrows_result.successful?
        name_arrow_result = draw_named_arrow(from: objects.first, to: objects.last, name: name)
        check([link_arrows_result, name_arrow_result])
      else
        link_arrows_result
      end
    end

    def draw_chained_composition(arrows:)
      composition_results = arrows.each_cons(2).map do |l,r|
        compose_arrows(r,l)
      end
      check composition_results
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

    def handle_multiple(commands:)
      results = commands.map do |command|
        handle(command: command)
      end
      check results
    end

    def handle(command:)
      case command
      when Noop then
        ok('(no-op)')
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
      when DrawNamedArrowLinksCommand then
        draw_named_arrow_links(
          name: command.name,
          objects: command.objects
        )
      else
        raise("Unknown command type, may need to implement a command handler for #{command.class}..")
      end
    end

    protected
    def create_anonymous_arrow(to:,from:)
      return err("Arrows can't point to arrows") if @env.arrows.map(&:name).any? { |nm| nm == to || nm == from }
      if @env.arrows.any? { |arrow| arrow.from == from && arrow.to == to }
        ok("arrow already exists between #{from} and #{to}")
      else
        @env.arrows << Arrow.new(from: from, to: to)
        ok("created anonymous arrow from #{from} to #{to}")
      end
    end

    def create_or_name_arrow(name:,to:,from:)
      return err("Arrows can't point to arrows") if @env.arrows.map(&:name).any? { |nm| nm == to || nm == from }
      return err("Objects can't also be arrows") if @env.objects.any? { |obj| name == obj } || (to == name) || (from == name)
      if (existing_arrow=@env.arrows.detect { |arrow| arrow.from == from && arrow.to == to })
        if existing_arrow.name.nil?
          return err("Arrow names must be unique") if @env.arrows.any? { |arrow| arrow.name == name }
          # is this a valid name??
          existing_arrow.name = name
          ok("unnamed arrow from #{from} to #{to} was given name #{name}")
        else
          ok("named arrow #{name} already exists between #{from} and #{to}")
        end
      else
        return err("Arrow names must be unique") if @env.arrows.any? { |arrow| arrow.name == name }
        @env.arrows << Arrow.new(from: from, to: to, name: name)
        ok("created arrow named #{name} from #{from} to #{to}")
      end
    end

    def check(results)
      message = if results.map(&:message).uniq.length == 1
                  results.first.message
                else
                  results.map(&:message).join('; ')
                end

      if results.all?(&:successful?)
        ok message
      else
        err message
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
