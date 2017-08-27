require "spec_helper"

describe "wildcard processing" do
  let(:callback_invocations) { @callback_invocations ||= [] }

  let(:queue) do
    queue = Postqueue.new
    queue.on "*" do |op, entity_ids|
      callback_invocations << [ op, entity_ids ]
    end
  end

  let(:items) { queue.item_class.all }
  let(:item)  { queue.item_class.first }

  context "when enqueuing in sync mode" do
    before do
      queue.enqueue op: "op", entity_id: 12
      queue.process
    end

    it "processed the items" do
      expect(callback_invocations.length).to eq(1)
    end

    it "removed all items" do
      expect(items.count).to eq(0)
    end
  end
end
