require "spec_helper"

describe "processing" do
  let(:processed_events) do
    @processed_events ||= []
  end

  let(:queue) do
    Postqueue.new do |queue|
      queue.batch_sizes["batchable"] = 10
      queue.batch_sizes["other-batchable"] = 10

      queue.on "*" do |op, entity_ids|
        processed_events << [ op, entity_ids ]
      end
    end
  end

  let(:items) { queue.item_class.all }
  let(:item)  { queue.item_class.first }

  describe "basics" do
    before do
      queue.enqueue op: "myop", entity_id: 12
      queue.enqueue op: "myop", entity_id: 13
      queue.enqueue op: "myop", entity_id: 14
    end

    it "processes the first entry" do
      r = queue.process_one
      expect(r).to eq(1)
      expect(items.map(&:entity_id)).to contain_exactly(13, 14)
    end

    it "honors search conditions" do
      queue.enqueue(op: "otherop", entity_id: 112)

      r = queue.process_one(op: "otherop")
      expect(r).to eq(1)
      expect(items.map(&:entity_id)).to contain_exactly(12, 13, 14)
    end

    it "yields a block and returns the processed entries" do
      queue.enqueue op: "otherop", entity_id: 112
      called = false
      queue.process_one(op: "otherop")

      op, ids = processed_events.first
      expect(op).to eq("otherop")
      expect(ids).to eq([112])

      expect(items.map(&:entity_id)).to contain_exactly(12, 13, 14)
    end
  end

  context "when having entries with different entity_type and op" do
    before do
      queue.enqueue op: "batchable", entity_id: 12
      queue.enqueue op: "batchable", entity_id: 13
      queue.enqueue op: "other-batchable", entity_id: 14
      queue.enqueue op: "batchable", entity_id: 15
      queue.enqueue op: "other-batchable", entity_id: 16
    end

    it "processes one matching entry with batch_size 1" do
      r = queue.process batch_size: 1
      expect(r).to eq(1)
      expect(items.map(&:entity_id)).to contain_exactly(13, 14, 15, 16)
    end

    it "processes two matching entries" do
      r = queue.process batch_size: 2
      expect(r).to eq(2)
      expect(items.map(&:entity_id)).to contain_exactly(14, 15, 16)
    end

    it "processes all matching entries" do
      r = queue.process
      expect(r).to eq(3)
      expect(items.map(&:entity_id)).to contain_exactly(14, 16)
    end

    it "honors search conditions" do
      r = queue.process(op: "other-batchable")
      expect(r).to eq(2)
      expect(items.map(&:entity_id)).to contain_exactly(12, 13, 15)
    end
  end
end
