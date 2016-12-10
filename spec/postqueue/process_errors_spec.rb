require 'spec_helper'

describe "::Postqueue.process_one" do
  class E < RuntimeError; end

  before do
    Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
  end

  it "fails when block raises an exception and reraises the exception" do
    expect { Postqueue.process_one do |op, type, ids| raise E end }.to raise_error(E)
    expect(items.map(&:entity_id)).to contain_exactly(12)
  end

  it "fails when block returns false" do
    Postqueue.process_one do |op, type, ids| false end
    expect(items.map(&:entity_id)).to contain_exactly(12)
  end

  it "keeps item in the queue after failure, with an increased failed_attempt count" do
    called_block = 0
    Postqueue.process_one do called_block += 1; false end
    expect(called_block).to eq(1)

    expect(items.map(&:entity_id)).to contain_exactly(12)
    expect(items.first.failed_attempts).to eq(1)
  end

  it "ignores items with a failed_attempt count > MAX_ATTEMPTS" do
    expect(Postqueue::MAX_ATTEMPTS).to be >= 3
    items.update_all(failed_attempts: 3)

    called_block = 0
    r = Postqueue.process_one do called_block += 1; false end
    expect(r).to eq(nil)
    expect(called_block).to eq(0)

    expect(items.map(&:entity_id)).to contain_exactly(12)
    expect(items.first.failed_attempts).to eq(3)
  end
end
