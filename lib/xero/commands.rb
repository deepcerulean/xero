module Xero
  module Commands
    class Command; end
    class Noop < Command; end
    class QueryEntityCommand < Command
      attr_reader :name
      def initialize(name:)
        @name = name
      end
    end

    class QueryArrowCommand < Command
      attr_reader :source, :target
      def initialize(source:, target:)
        @source = source
        @target = target
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

    class DrawNamedCompositionCommand < Command
      attr_reader :name, :first_arrow, :second_arrow
      def initialize(name:, first_arrow:, second_arrow:)
        @name = name
        @first_arrow = first_arrow
        @second_arrow = second_arrow
      end
    end

    # this 'returns' something...
    class DrawLinkedArrowsCommand < Command
      attr_reader :objects
      def initialize(objects:)
        @objects = objects
      end
    end

    class DrawNamedArrowLinksCommand < Command
      attr_reader :name, :objects
      def initialize(name:, objects:)
        @name = name
        @objects = objects
      end
    end

    class CommandList < Command
      attr_reader :subcommands
      def initialize(subcommands:)
        @subcommands = subcommands
      end
    end

    # perform a chain composition: h.g.f
    class DrawChainedCompositionCommand < Command
      attr_reader :arrows
      def initialize(arrows:)
        @arrows = arrows
      end
    end

    class DrawNamedCompositionChainCommand < Command
      attr_reader :name, :arrows
      def initialize(name:, arrows:)
        @name = name
        @arrows = arrows
      end
    end
  end
end
