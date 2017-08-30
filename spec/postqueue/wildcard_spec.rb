require "spec_helper"

describe "wildcard processing" do
  let(:callback_invocations) { @callback_invocations ||= [] }

  let(:queue) do
    Postqueue.on "*" do |op, entity_ids|
      callback_invocations << [ op, entity_ids ]
    end
    Postqueue.new
  end

  context "when enqueuing in sync mode" do
    before do
      queue.enqueue op: "op", entity_id: 12
      queue.process
    end

    it "processed the items" do
      expect(callback_invocations.length).to eq(1)
    end

    it "removed all items" do
      expect(queue.items.count).to eq(0)
    end
  end
end
