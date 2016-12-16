require "spec_helper"

describe "idempotent operations" do
  let(:queue) do
    Postqueue.new do |queue|
      queue.batch_sizes["batchable"] = 10
      queue.idempotent_operation "idempotent"
    end
  end

  let(:items) { queue.item_class.all }
  let(:item)  { queue.item_class.first }

  context "when enqueueing many entries" do
    before do
      queue.enqueue op: "idempotent", entity_id: 12
      queue.enqueue op: "idempotent", entity_id: 13
      queue.enqueue op: "idempotent", entity_id: 12
      queue.enqueue op: "idempotent", entity_id: 12
      queue.enqueue op: "idempotent", entity_id: 12
      queue.enqueue op: "no-duplicate", entity_id: 14
      queue.enqueue op: "no-duplicate", entity_id: 14
    end

    it "does not skip non-duplicates" do
      entity_ids = items.select { |i| i.op == "no-duplicate" }.map(&:entity_id)
      expect(entity_ids).to eq([14, 14])
    end

    it "skips duplicates" do
      entity_ids = items.select { |i| i.op == "idempotent" }.map(&:entity_id)
      expect(entity_ids).to eq([12, 13])
    end
  end

  context "when enqueueing many entries" do
    it "skips duplicates in entries" do
      queue.enqueue op: "idempotent", entity_id: 12
      queue.enqueue op: "idempotent", entity_id: [13, 12, 12, 13, 14]
      queue.enqueue op: "idempotent", entity_id: 14
      expect(items.map(&:entity_id)).to eq([12, 13, 14])
    end
  end

  context "when processing entries" do
    let(:callback_invocations) { @callback_invocations ||= [] }

    before do
      queue.enqueue op: "idempotent", entity_id: 12
      queue.item_class.insert_item(op: "idempotent", entity_id: 12)

      queue.on "idempotent" do |op, entity_ids|
        callback_invocations << [ op, entity_ids ]
      end
      queue.process
    end

    it "runs the process callback only once" do
      expect(callback_invocations.length).to eq(1)
    end

    it "removes all items" do
      expect(items.count).to eq(0)
    end
  end
end
