require "spec_helper"

describe "Process::Queue processing" do
  let(:now) { Time.now }
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

  describe "process_one" do
    before do
      queue.enqueue op: "myop", entity_id: 12
      queue.enqueue op: "myop", entity_id: 13
      queue.enqueue op: "myop", entity_id: 14

      queue.items.update_all(next_run_at: now)
      queue.items.where(entity_id: 13).update_all(next_run_at: (now - 1.day))

      @result = queue.process_one
    end

    it "returns the number of processed items" do
      expect(@result).to eq(1)
    end

    it "processed the entry with the lowest next_run_at time" do
      expect(processed_events).to eq([["myop", [13]]])
    end

    it "removes the processed entry" do
      expect(queue.items.pluck(:entity_id)).to contain_exactly(12, 14)
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
