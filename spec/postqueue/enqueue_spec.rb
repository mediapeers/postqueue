require "spec_helper"

describe "enqueuing" do
  class TestQueue < Postqueue::Base
    def idempotent?(entity_type:, op:)
      _ = op
      entity_type == "idempotent"
    end
  end

  let(:queue) { TestQueue.new }

  let(:item) { Postqueue::Item.first }

  context "when enqueueing entries" do
    before do
      queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
    end

    it "enqueues items" do
      expect(item.op).to eq("myop")
      expect(item.entity_type).to eq("mytype")
      expect(item.entity_id).to eq(12)
    end

    it "sets defaults" do
      expect(item.created_at).to be > (Time.now - 1.second)
      expect(item.next_run_at).to be > (Time.now - 1.second)
      expect(item.failed_attempts).to eq(0)
    end
  end

  context "when enqueueing identical idempotent entries" do
    it "skips later duplicates" do
      queue.enqueue op: "myop", entity_type: "idempotent", entity_id: 12
      queue.enqueue op: "myop", entity_type: "idempotent", entity_id: 13
      queue.enqueue op: "myop", entity_type: "idempotent", entity_id: 12
      queue.enqueue op: "myop", entity_type: "idempotent", entity_id: 12
      queue.enqueue op: "myop", entity_type: "idempotent", entity_id: 12

      expect(items.map(&:entity_id)).to eq([12, 13])
    end
  end

  context "when enqueueing many entries" do
    it "adds all entries skipping duplicates" do
      queue.enqueue op: "myop", entity_type: "idempotent", entity_id: 12
      queue.enqueue op: "myop", entity_type: "idempotent", entity_id: [13, 12, 12, 13, 14]
      expect(items.map(&:entity_id)).to eq([12, 13, 14])
    end
  end
end
