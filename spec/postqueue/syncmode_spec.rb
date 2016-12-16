require "spec_helper"

describe "enqueuing" do
  let(:callback_invocations) { @callback_invocations ||= [] }

  before :all do
    Postqueue.async_processing = false
  end

  after :all do
    Postqueue.async_processing = true
  end

  let(:queue) do
    Postqueue.new do |queue|
      queue.on "op" do |op, entity_ids|
        callback_invocations << [ op, entity_ids ]
      end
    end
  end

  let(:items) { queue.item_class.all }
  let(:item)  { queue.item_class.first }

  context "when enqueuing in sync mode" do
    before do
      queue.enqueue op: "op", entity_id: 12
    end

    it "processed the items" do
      expect(callback_invocations.length).to eq(1)
    end

    it "removed all items" do
      expect(items.count).to eq(0)
    end
  end
end
