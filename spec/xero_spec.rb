require 'spec_helper'
require 'xero'

describe Xero do
  it "should have a VERSION constant" do
    expect(subject.const_get('VERSION')).to_not be_empty
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

  it 'can handle multiple statements separated by semicolons' do
    tokens = tokenizer.analyze('a -> b; c -> d')
    ast = parser.analyze(tokens)
    cmd = interpreter.analyze(ast)

    expect(cmd).to be_a(CommandList)
    expect(cmd.subcommands.first).to be_a(DrawArrowCommand)
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

  it 'executes a compose objects command' do
    result = processor.evaluate('hello -> world')

    expect(result).to be_a(CommandResult)
    expect(result).to be_successful

    expect(environment.arrows.count).to eq(1)
    the_arrow = environment.arrows.first
    expect(the_arrow.from).to eq('hello')
    expect(the_arrow.to).to eq('world')
  end

  it 'executes a definition command' do
    result = processor.evaluate('hello: there -> world')
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
