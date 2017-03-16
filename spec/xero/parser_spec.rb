require 'spec_helper'
require 'xero/tokenizer'
require 'xero/parser'

describe Parser do
  let(:tokenizer) do
    Tokenizer.new
  end

  let(:parser) do
    Parser.new
  end

  describe 'assembles tokens into trees' do
    it 'can analyze a simple operation' do
      tokens = tokenizer.analyze('hello -> world')
      ast = parser.analyze(tokens)
      expect(ast).to be_a(ExpressionNode)
      expect(ast).to be_a(OperationNode)

      node = ast
      expect(node.left).to be_a(LabelNode)
      expect(node.left.value).to eq('hello')

      expect(node.value).to eq(:arrow)

      expect(node.right).to be_a(LabelNode)
      expect(node.right.value).to eq('world')
    end

    it 'can analyze a more complex operation' do
      tokens = tokenizer.analyze('hello -> there -> world')
      ast = parser.analyze(tokens)
      expect(ast).to be_a(ExpressionNode)
      expect(ast).to be_a(OperationNode)

      root_node = ast
      expect(root_node.value).to eq(:arrow)
      expect(root_node.left).to be_a(LabelNode)
      expect(root_node.left.value).to eq('hello')

      right_node = root_node.right
      expect(right_node).to be_a(OperationNode)
      expect(right_node.value).to eq(:arrow)
      expect(right_node.left.value).to eq('there')
      expect(right_node.right.value).to eq('world')
    end

    it 'can analyze a definition' do
      tokens = tokenizer.analyze('hello: there -> world')
      ast = parser.analyze(tokens)
      expect(ast).to be_a(ExpressionNode)
      expect(ast).to be_a(OperationNode)

      root_node = ast
      expect(root_node.value).to eq(:defn)
      expect(root_node.left).to be_a(LabelNode)
      expect(root_node.left.value).to eq('hello')

      right_node = root_node.right
      expect(right_node).to be_a(OperationNode)
      expect(right_node.value).to eq(:arrow)
      expect(right_node.left.value).to eq('there')
      expect(right_node.right.value).to eq('world')
    end

    it 'can analyze a series of statements' do
      tokens = tokenizer.analyze('a -> b; c -> d')
      ast = parser.analyze(tokens)
      expect(ast).to be_a(ExpressionNode)
      expect(ast).to be_a(StatementListNode)
      expect(ast.statements.length).to eq(2)
      # expect(ast).to be_a(ProgramNode)
    end
  end
end
