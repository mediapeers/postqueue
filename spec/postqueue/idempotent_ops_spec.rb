require "spec_helper"

describe "idempotent operations" do
  let(:callback_invocations) { @callback_invocations ||= [] }

  let(:queue) do
    Postqueue.on "idempotent", idempotent: true do |op, entity_ids|
      callback_invocations << [ op, entity_ids ]
    end
    Postqueue.new
  end

  context "when enqueueing entries" do
    before do
      queue.enqueue op: "idempotent", entity_id: 12
      queue.enqueue op: "idempotent", entity_id: 13
      queue.enqueue op: "idempotent", entity_id: 12
      queue.enqueue op: "idempotent", entity_id: 12
      queue.enqueue op: "idempotent", entity_id: [13, 12, 12, 13, 11]
      queue.enqueue op: "no-duplicate", entity_id: 14
      queue.enqueue op: "no-duplicate", entity_id: 14
    end

    it "does not skip duplicates of non-idempotent items" do
      entity_ids = queue.items.where(op: "no-duplicate").map(&:entity_id)
      expect(entity_ids).to eq([14, 14])
    end

    it "skips duplicates of idempotent items" do
      entity_ids = queue.items.where(op: "idempotent").map(&:entity_id)
      expect(entity_ids).to eq([12, 13, 11])
    end
  end

  context "when processing entries" do
    before do
      queue.enqueue op: "idempotent", entity_id: 12
      queue.items.insert_item(op: "idempotent", entity_id: 12)
      queue.process
    end

    it "runs the process callback only once" do
      expect(callback_invocations.length).to eq(1)
    end

    it "removes all items" do
      expect(queue.items.count).to eq(0)
    end
  end
end
