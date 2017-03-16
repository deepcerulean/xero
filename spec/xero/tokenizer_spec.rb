require 'spec_helper'
require 'xero/tokenizer'

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

