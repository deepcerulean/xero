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

  it 'should analyze strings with labels and arrows into tokens' do
    tokens = tokenizer.analyze('hello -> world')
    expect(tokens.length).to eq(5)
    expect(tokens.first).to be_a(LabelToken)
    expect(tokens.first.content).to eq('hello')
    expect(tokens.map(&:class)).to eq([LabelToken, WhitespaceToken, ArrowToken, WhitespaceToken, LabelToken])
    expect(tokens.map(&:content)).to eq(['hello', ' ', '->', ' ', 'world'])
  end

  it 'should analyze a string with labels and dots' do
    tokens = tokenizer.analyze('there . world')
    expect(tokens.length).to eq(5)
    expect(tokens.first).to be_a(LabelToken)
    expect(tokens.first.content).to eq('there')
    expect(tokens.map(&:class)).to eq([LabelToken, WhitespaceToken, DotToken, WhitespaceToken, LabelToken])
    expect(tokens.map(&:content)).to eq(['there', ' ', '.', ' ', 'world'])
  end

  it 'should analyze a string with labels and dots' do
    tokens = tokenizer.analyze('hello -> world; there . world')
    expect(tokens.length).to eq(12)
    expect(tokens.first).to be_a(LabelToken)
    expect(tokens.first.content).to eq('hello')
    expect(tokens.map(&:class)).to eq([LabelToken, WhitespaceToken, ArrowToken, WhitespaceToken, LabelToken, SemicolonToken, WhitespaceToken, LabelToken, WhitespaceToken, DotToken, WhitespaceToken, LabelToken])
    expect(tokens.map(&:content)).to eq(['hello', ' ', '->', ' ', 'world', ';', ' ', 'there', ' ', '.', ' ', 'world'])
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
    expect(cmd).to be_a(DrawNamedArrowCommand)

    expect(cmd.name).to eq('hello')
    expect(cmd.source).to eq('there')
    expect(cmd.target).to eq('world')
  end

  it 'can navigate chained ops' do
    tokens = tokenizer.analyze('hello -> there -> world')
    ast = parser.analyze(tokens)
    cmd = interpreter.analyze(ast)

    expect(cmd).to be_a(DrawLinkedArrowsCommand)
    expect(cmd.objects).to contain_exactly('hello', 'there', 'world')
  end

  it 'can handle dots' do
    tokens = tokenizer.analyze('f . g')
    ast = parser.analyze(tokens)
    cmd = interpreter.analyze(ast)

    expect(cmd).to be_a(ComposeArrowsCommand)
    expect(cmd.source).to eq('f') #contain_exactly('f', 'g')
    expect(cmd.target).to eq('g')
  end
end

xdescribe Evaluator

describe Arrow do
  subject(:arrow) do
    Arrow.new(from: 'source', to: 'target')
  end

  it 'has a source and target' do
    expect(arrow.from).to eq('source')
    expect(arrow.to).to eq('target')
  end

  it 'can be composed' do
    another_arrow = Arrow.new(from: 'target', to: 'another_target')
    composed = another_arrow.compose(arrow)
    expect(composed.from).to eq('source')
    expect(composed.to).to eq('another_target')
  end
end

describe Processor do
  subject(:processor) { Processor.new(environment: environment) }
  let(:environment) { Environment.new }

  let(:evaluator) do
    Evaluator.new
  end

  it 'executes a compose objects command' do
    cmd    = evaluator.determine('hello -> world')
    result = processor.execute(cmd)

    expect(result).to be_a(CommandResult)
    expect(result).to be_successful

    expect(environment.arrows.count).to eq(1)
    the_arrow = environment.arrows.first
    expect(the_arrow.from).to eq('hello')
    expect(the_arrow.to).to eq('world')
  end

  it 'executes a definition command' do
    cmd    = evaluator.determine('hello: there -> world')
    result = processor.execute(cmd)

    expect(result).to be_a(CommandResult)
    expect(result).to be_successful
    new_arrow = environment.arrows.detect { |arr| arr.name == 'hello' }
    expect(new_arrow.from).to eq('there')
    expect(new_arrow.to).to eq('world')
  end

  it 'executes a compose arrows command' do
    processor.evaluate('f: a -> b')
    processor.evaluate('g: b -> c')

    result = processor.evaluate('h: g . f')
    expect(result).to be_a(CommandResult)
    expect(result).to be_successful

    new_arrow = environment.arrows.detect { |arr| arr.name == 'h' }
    expect(new_arrow.from).to eq('a')
    expect(new_arrow.to).to eq('c')
  end

  it 'executes a linked arrows command' do
    result = processor.evaluate('a -> b -> c')
    expect(result).to be_a(CommandResult)
    expect(result).to be_successful

    expect(environment.objects).to contain_exactly('a', 'b', 'c')
  end

  it 'executes a query named entity command' do
    processor.evaluate('hello -> there')
    expect(environment.objects).to contain_exactly('hello', 'there')

    result = processor.evaluate('hello')
    expect(result).to be_a(CommandResult)
    expect(result).to be_successful
  end

  it 'will not make arrows out of objects' do
    processor.evaluate('f: a -> b')
    expect { processor.evaluate('a: x -> y') }.to raise_error(RuntimeError, "Objects can't also be arrows")
  end
end
