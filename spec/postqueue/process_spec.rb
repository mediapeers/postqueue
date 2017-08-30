require "spec_helper"

describe "processing" do
  let(:processed_events) do
    @processed_events ||= []
  end

  let(:queue) do
    Postqueue.on "batchable", batch_size: 10
    Postqueue.on "other-batchable", batch_size: 10
    Postqueue.on "*" do |op, entity_ids|
      processed_events << [ op, entity_ids ]
    end
    Postqueue.new
  end

  describe "basics" do
    before do
      queue.enqueue op: "myop", entity_id: 12
      queue.enqueue op: "myop", entity_id: 13
      queue.enqueue op: "myop", entity_id: 14
    end

    it "processes the first entry" do
      r = queue.process_one
      expect(r).to eq(1)
      expect(queue.items.pluck(:entity_id)).to contain_exactly(13, 14)
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
      expect(queue.items.pluck(:entity_id)).to contain_exactly(13, 14, 15, 16)
    end

    it "processes two matching entries" do
      r = queue.process batch_size: 2
      expect(r).to eq(2)
      expect(queue.items.pluck(:entity_id)).to contain_exactly(14, 15, 16)
    end

    it "processes all matching entries" do
      r = queue.process
      expect(r).to eq(3)
      expect(queue.items.pluck(:entity_id)).to contain_exactly(14, 16)
    end
  end
end
