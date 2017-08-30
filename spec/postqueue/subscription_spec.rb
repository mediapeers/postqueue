require "spec_helper"

describe "subscriptions" do
  let(:queue) { Postqueue.new }

  context "when enqueueing an item with a specific channel" do
    before do
      queue.enqueue op: "myop", entity_id: 12, channel: "foo"
    end

    it "adds the item only to that channel" do
      expect(queue.items.where(entity_id: 12).pluck(:channel)).to contain_exactly("foo")
    end
  end

  context "when enqueueing an item without a specific channel" do
    context "when two channels subscribed to that op" do
      before do
        queue.subscribe op: "myop", channel: "sub1"
        queue.subscribe op: "myop", channel: "sub2"
        queue.subscribe op: "otherop", channel: "sub3"
        queue.enqueue op: "myop", entity_id: 12
      end

      it "adds the item to these channels and to the default channel only to that channel" do
        expect(queue.items.where(entity_id: 12).pluck(:channel)).to contain_exactly(nil, "sub1", "sub2")
      end
    end
  end
end
