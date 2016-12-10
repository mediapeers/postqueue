require 'spec_helper'

describe "::queue.process_one" do
  let(:queue) { Postqueue.new }

  before do
    queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
    queue.enqueue op: "myop", entity_type: "mytype", entity_id: 13
    queue.enqueue op: "myop", entity_type: "mytype", entity_id: 14
  end

  let(:processor) { Postqueue::Processor.new }

  it "processes one entry" do
    r = queue.process_one
    expect(r).to eq(["myop", "mytype", [12]])
    expect(items.map(&:entity_id)).to contain_exactly(13, 14)
  end

  it "honors search conditions" do
    queue.enqueue op: "otherop", entity_type: "mytype", entity_id: 112

    r = queue.process_one(where: { op: "otherop" })
    expect(r).to eq(["otherop", "mytype", [112]])
    expect(items.map(&:entity_id)).to contain_exactly(12, 13, 14)
  end

  it "yields a block and returns it" do
    queue.enqueue op: "otherop", entity_type: "mytype", entity_id: 112 
    r = queue.process_one(where: { op: "otherop" }) do |op, type, ids|
      expect(op).to eq("otherop")
      expect(type).to eq("mytype")
      expect(ids).to eq([112])
      "yihaa"
    end

    expect(r).to eq("yihaa")
    expect(items.map(&:entity_id)).to contain_exactly(12, 13, 14)
  end
end
