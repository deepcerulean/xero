require 'spec_helper'
require 'xero/repl'

describe Repl do
  subject(:repl) do
    described_class.new(processor: processor)
  end

  let(:processor) { double('Processor') }

  it 'should do stuff' do
    expect(repl).to be_halted
    Thread.new { repl.launch! }
    sleep(0.2)
    expect(repl).not_to be_halted
    repl.halt!
    expect(repl).to be_halted
  end
end
