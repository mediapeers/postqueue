require "spec_helper"

describe "enqueuing" do
  let(:queue) { Postqueue.new }
  let(:items) { queue.item_class.all }
  let(:item)  { queue.item_class.first }

  context "when enqueueing individual items" do
    before do
      queue.enqueue op: "myop", entity_id: 12
    end

    it "enqueues items" do
      expect(item.op).to eq("myop")
      expect(item.entity_id).to eq(12)
    end

    it "enqueues arrays" do
      queue.enqueue op: "myop", entity_id: [13, 14, 15]
      expect(items.pluck(:entity_id)).to eq([12, 13, 14, 15])
    end

    it "enqueues sets" do
      queue.enqueue op: "myop", entity_id: Set.new([13, 14, 15])
      expect(items.pluck(:entity_id)).to eq([12, 13, 14, 15])
    end

    it "sets defaults" do
      expect(item.created_at).to be > (Time.now - 1.second)
      expect(item.next_run_at).to be > (Time.now - 1.second)
      expect(item.failed_attempts).to eq(0)
    end
  end
end
