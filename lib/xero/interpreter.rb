module Xero
  class Interpreter
    include Commands
    def analyze(ast)
      return Noop.new if ast.nil? # do not need to explode on a noop
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

    protected
    def defn(ast)
      raise "Definition name #{label} is not a label" unless ast.left.is_a?(LabelNode)
      name = ast.left.value
      arrow_cmd = analyze(ast.right)
      case arrow_cmd
      when ComposeArrowsCommand then
        DrawNamedCompositionCommand.new(name: name, first_arrow: arrow_cmd.source, second_arrow: arrow_cmd.target)
      when DrawArrowCommand then
        DrawNamedArrowCommand.new(name: name, source: arrow_cmd.source, target: arrow_cmd.target)
      when DrawLinkedArrowsCommand then
        DrawNamedArrowLinksCommand.new(name: name, objects: arrow_cmd.objects)
      when DrawChainedCompositionCommand then
        DrawNamedCompositionChainCommand.new(name: name, arrows: arrow_cmd.arrows)
      else
        raise "Unknown type of definition (not arrow or composition of arrows): #{arrow_cmd}"
      end
    end

    def arrow(ast)
      if ast.left.is_a?(LabelNode) && ast.right.is_a?(LabelNode)
        DrawArrowCommand.new(source: ast.left.value, target: ast.right.value)
      else
        if ast.left.is_a?(LabelNode)
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
    end

    def dot(ast)
      raise "First element of a composition must be a label" unless ast.left.is_a?(LabelNode)
      if ast.right.is_a?(LabelNode)
        ComposeArrowsCommand.new(source: ast.left.value, target: ast.right.value)
      else
        right_cmd = analyze(ast.right)
        case right_cmd
        when ComposeArrowsCommand then # meld with this one composition, linking three arrows
          DrawChainedCompositionCommand.new(arrows: [ast.left.value, right_cmd.source, right_cmd.target])
        when DrawChainedCompositionCommand then # meld with arrows arr
          DrawChainedCompositionCommand.new(arrows: [ast.left.value] + right_cmd.arrows)
        end
      end
    end

    # deref an arrow by source and target (iff it can be found by composition of already drawn arrows)
    def route(ast)
      if ast.left.is_a?(LabelNode) && ast.right.is_a?(LabelNode)
        QueryRouteCommand.new(origin: ast.left.value, destination: ast.right.value)
      else
        raise 'can only route between labelled objs'
      end
    end

    def analyze_operation(ast)
      case ast.value
      when :defn  then defn(ast)
      when :arrow then arrow(ast)
      when :dot   then dot(ast)
      when :route then route(ast)
      else
        raise "unknown operation type #{ast.value} (expecting :defn, :arrow, :dot, :route): #{ast}"
      end
    end
  end
end
