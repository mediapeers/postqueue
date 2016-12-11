require "spec_helper"

describe "enqueuing" do
  let(:queue) { Postqueue::Base.new }
  let(:item)  { queue.items.first }

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
      queue.enqueue op: "duplicate", entity_id: 12, duplicate: duplicate
      queue.enqueue op: "duplicate", entity_id: 13, duplicate: duplicate
      queue.enqueue op: "duplicate", entity_id: 12, duplicate: duplicate
      queue.enqueue op: "duplicate", entity_id: 12, duplicate: duplicate
      queue.enqueue op: "duplicate", entity_id: 12, duplicate: duplicate
      queue.enqueue op: "no-duplicate", entity_id: 13, duplicate: duplicate
    end

    context "when duplicates are permitted" do
      let(:duplicate) { true }

      it "does not skip duplicates" do
        expect(items.map(&:entity_id)).to eq([12, 13, 12, 12, 12, 13])
      end
    end

    context "when duplicates are not permitted" do
      let(:duplicate) { false }

      it "skips later duplicates" do
        expect(items.map(&:entity_id)).to eq([12, 13, 13])
      end
    end
  end

  context "when enqueueing many entries" do
    it "adds all entries skipping duplicates" do
      queue.enqueue op: "duplicate", entity_id: 12, duplicate: false
      queue.enqueue op: "duplicate", entity_id: [13, 12, 12, 13, 14], duplicate: false
      expect(items.map(&:entity_id)).to eq([12, 13, 14])
    end
  end
end
