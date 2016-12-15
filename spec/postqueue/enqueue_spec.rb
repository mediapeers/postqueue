require "spec_helper"

describe "enqueuing" do
  let(:queue) do
    Postqueue.new do |queue|
      queue.default_batch_size = 1
      queue.batch_sizes["batchable"] = 10
      queue.batch_sizes["other-batchable"] = 10
    end
  end

  let(:items) { queue.item_class.all }
  let(:item)  { queue.item_class.first }

  context "when enqueueing entries" do
    before do
      queue.enqueue op: "myop", entity_id: 12
    end

    it "enqueues items" do
      expect(item.op).to eq("myop")
      expect(item.entity_id).to eq(12)
    end

    it "sets defaults" do
      expect(item.created_at).to be > (Time.now - 1.second)
      expect(item.next_run_at).to be > (Time.now - 1.second)
      expect(item.failed_attempts).to eq(0)
    end
  end

  context "when enqueueing identical duplicate entries" do
    before do
      queue.enqueue op: "duplicate", entity_id: 12, ignore_duplicates: ignore_duplicates
      queue.enqueue op: "duplicate", entity_id: 13, ignore_duplicates: ignore_duplicates
      queue.enqueue op: "duplicate", entity_id: 12, ignore_duplicates: ignore_duplicates
      queue.enqueue op: "duplicate", entity_id: 12, ignore_duplicates: ignore_duplicates
      queue.enqueue op: "duplicate", entity_id: 12, ignore_duplicates: ignore_duplicates
      queue.enqueue op: "no-duplicate", entity_id: 13, ignore_duplicates: ignore_duplicates
    end

    context "when duplicates are permitted" do
      let(:ignore_duplicates) { false }

      it "does not skip duplicates" do
        expect(items.map(&:entity_id)).to eq([12, 13, 12, 12, 12, 13])
      end
    end

    context "when duplicates are not permitted" do
      let(:ignore_duplicates) { true }

      it "skips later duplicates" do
        expect(items.map(&:entity_id)).to eq([12, 13, 13])
      end
    end
  end

  context "when enqueueing many entries" do
    it "adds all entries skipping duplicates" do
      queue.enqueue op: "duplicate", entity_id: 12, ignore_duplicates: true
      queue.enqueue op: "duplicate", entity_id: [13, 12, 12, 13, 14], ignore_duplicates: true
      expect(items.map(&:entity_id)).to eq([12, 13, 14])
    end
  end
end
