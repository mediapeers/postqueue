require 'spec_helper'

describe "::Postqueue.process_one" do
  before do
    Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
    Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 13
    Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 14
  end

  it "processes one entry" do
    r = Postqueue.process_one
    expect(r).to eq(["myop", "mytype", [12]])
    expect(items.map(&:entity_id)).to contain_exactly(13, 14)
  end

  it "honors search conditions" do
    Postqueue.enqueue op: "otherop", entity_type: "mytype", entity_id: 112

    r = Postqueue.process_one(where: { op: "otherop" })
    expect(r).to eq(["otherop", "mytype", [112]])
    expect(items.map(&:entity_id)).to contain_exactly(12, 13, 14)
  end

  it "yields a block and returns it" do
    Postqueue.enqueue op: "otherop", entity_type: "mytype", entity_id: 112 
    r = Postqueue.process_one(where: { op: "otherop" }) do |op, type, ids|
      expect(op).to eq("otherop")
      expect(type).to eq("mytype")
      expect(ids).to eq([112])
      "yihaa"
    end

    expect(r).to eq("yihaa")
    expect(items.map(&:entity_id)).to contain_exactly(12, 13, 14)
  end
end
