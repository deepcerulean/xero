module Xero
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

  class StatementListNode < ExpressionNode
    def initialize; end
    def <<(stmt); statements.push(stmt); end
    def statements; @stmts ||= [] end
    def to_s(depth: 1)
      tabs = "\n" + (' ' * depth)
      list = statements.map {|stmt| tabs + " - " + stmt.to_s(depth: depth+1) }
      tabs + "#{self.class.name}\n" +
        tabs + "list:\n#{list}\n"
    end
    alias :inspect :to_s
  end

  class Parser
    def analyze(tokens)
      tokens.reject! { |token| token.is_a?(WhitespaceToken) }
      expression(tokens)
    end

    protected
    def expression(tokens)
      raise "Empty statement is not an expression!" unless tokens.any?
      if tokens.length == 1
        the_token = tokens.first
        return label(the_token) if label(the_token)
      else
        statement_list(tokens) || operation(tokens) || (raise "could not parse statement: '#{tokens.map(&:to_s).join(' ')}'; was expecting a statement list or operation (maybe incomplete statement?)")
      end
    end

    def statement_list(tokens)
      if tokens.any? { |token| token.is_a?(SemicolonToken) }
        stmts = split(tokens, on: SemicolonToken)
        stmt_list = StatementListNode.new
        stmts.each do |stmt_tokens|
          stmt_list << operation(stmt_tokens)
        end
        stmt_list
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
        when DotToken then :dot
        when RouteToken then :route
        end
      end
    end

    def operation(tokens)
      first, second, *rest = tokens
      if label(first) && operator(second) && expression(rest)
        OperationNode.new(operator(second), left: label(first), right: expression(rest))
      end
    end

    private
    def split(tokens, on:)
      arr_lst = []
      curr = []
      tokens.each do |token|
        if token.is_a?(on)
          arr_lst.push(curr)
          curr = []
        else
          curr.push(token)
        end
      end
      arr_lst.push(curr)
      arr_lst
    end
  end
end
