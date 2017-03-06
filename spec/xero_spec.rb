require 'spec_helper'
require 'xero'

describe Xero do
  it "should have a VERSION constant" do
    expect(subject.const_get('VERSION')).to_not be_empty
  end
end

describe Tokenizer do
  let(:tokenizer) do
    Tokenizer.new
  end

  it 'should break strings into tokens' do
    tokens = tokenizer.analyze('hello -> world')
    expect(tokens.length).to eq(5)
    expect(tokens.first).to be_a(Label)
    expect(tokens.first.content).to eq('hello')
    expect(tokens.map(&:class)).to eq([Label, Whitespace, Arrow, Whitespace, Label])
    expect(tokens.map(&:content)).to eq(['hello', ' ', '->', ' ', 'world'])
  end
end

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
      expect(ast).to be_a(OperatorNode)

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
      expect(ast).to be_a(OperatorNode)

      root_node = ast
      expect(root_node.value).to eq(:arrow)
      expect(root_node.left).to be_a(LabelNode)
      expect(root_node.left.value).to eq('hello')

      right_node = root_node.right
      expect(right_node).to be_a(OperatorNode)
      expect(right_node.value).to eq(:arrow)
      expect(right_node.left.value).to eq('there')
      expect(right_node.right.value).to eq('world')
    end
  end
end
