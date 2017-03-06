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
  end
end

describe Interpreter do
  subject(:interpreter) { Interpreter.new }
  let(:tokenizer)       { Tokenizer.new }
  let(:parser)          { Parser.new }

  it 'can turn an ast into a command' do
    tokens = tokenizer.analyze('hello: there -> world')
    ast = parser.analyze(tokens)

    cmd = interpreter.analyze(ast)

    expect(cmd).to be_a(Command)
    expect(cmd).to be_a(CreateDefinitionCommand)

    expect(cmd.term).to eq('hello')
    expect(cmd.definition).to be_a(ComposeElementsCommand)
    expect(cmd.definition.left).to eq('there')
    expect(cmd.definition.right).to eq('world')
  end
end

describe Processor do
  subject(:processor) { Processor.new(environment: environment) }
  let(:environment) { SimpleEnvironment.new }

  let(:interpreter)   { Interpreter.new }
  let(:tokenizer)     { Tokenizer.new }
  let(:parser)        { Parser.new }

  it 'executes a command within an environment/frame' do
    tokens = tokenizer.analyze('hello: there -> world')
    ast    = parser.analyze(tokens)
    cmd    = interpreter.analyze(ast)

    result = processor.handle(cmd)

    expect(result).to be_a(CommandResult)
  end
end
