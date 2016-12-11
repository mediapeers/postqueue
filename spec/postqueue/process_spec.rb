require "spec_helper"

describe "::queue.process" do
  let(:queue) { Postqueue::Base.new }

  describe "basics" do
    before do
      queue.enqueue op: "myop", entity_id: 12
      queue.enqueue op: "myop", entity_id: 13
      queue.enqueue op: "myop", entity_id: 14
    end

    it "processes the first entry" do
      r = queue.process_one
      expect(r).to eq(["myop", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13, 14)
    end

    it "honors search conditions" do
      queue.enqueue(op: "otherop", entity_id: 112)

      r = queue.process_one(op: "otherop")
      expect(r).to eq(["otherop", [112]])
      expect(items.map(&:entity_id)).to contain_exactly(12, 13, 14)
    end

    it "yields a block and returns its return value" do
      queue.enqueue op: "otherop", entity_id: 112
      r = queue.process_one(op: "otherop") do |op, ids|
        expect(op).to eq("otherop")
        expect(ids).to eq([112])
        "yihaa"
      end

      expect(r).to eq("yihaa")
      expect(items.map(&:entity_id)).to contain_exactly(12, 13, 14)
    end
  end

  context "when having entries with different entity_type and op" do
    before do
      queue.enqueue op: "myop", entity_id: 12
      queue.enqueue op: "myop", entity_id: 13
      queue.enqueue op: "otherop", entity_id: 14
      queue.enqueue op: "myop", entity_id: 15
      queue.enqueue op: "otherop", entity_id: 16
    end

    it "processes one entries" do
      r = queue.process batch_size: 1
      expect(r).to eq(["myop", [12]])
      expect(items.map(&:entity_id)).to contain_exactly(13, 14, 15, 16)
    end

    it "processes two entries" do
      r = queue.process batch_size: 2
      expect(r).to eq(["myop", [12, 13]])
      expect(items.map(&:entity_id)).to contain_exactly(14, 15, 16)
    end

    it "processes only matching entries when asked for more" do
      r = queue.process
      expect(r).to eq(["myop", [12, 13, 15]])
      expect(items.map(&:entity_id)).to contain_exactly(14, 16)
    end

    it "honors search conditions" do
      r = queue.process(op: "otherop")
      expect(r).to eq(["otherop", [14, 16]])
      expect(items.map(&:entity_id)).to contain_exactly(12, 13, 15)
    end
  end
end
