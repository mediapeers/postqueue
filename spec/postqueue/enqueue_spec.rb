require "spec_helper"

describe "Postqueue::Queue#enqueue" do
  let(:queue) { Postqueue.new }

  it "enqueues items" do
    queue.enqueue op: "myop", entity_id: 12
    item = queue.items.first
    expect(item.op).to eq("myop")
    expect(item.entity_id).to eq(12)
  end

  it "enqueues arrays" do
    queue.enqueue op: "myop", entity_id: [13, 14, 15]
    expect(queue.items.pluck(:entity_id)).to contain_exactly(13, 14, 15)
  end

  it "enqueues sets" do
    queue.enqueue op: "myop", entity_id: Set.new([13, 14, 15])
    expect(queue.items.pluck(:entity_id)).to contain_exactly(13, 14, 15)
  end

  it "sets default attributes" do
    queue.enqueue op: "myop", entity_id: 12
    item = queue.items.first
    expect(item.created_at).to be > (Time.now - 1.second)
    expect(item.next_run_at).to be > (Time.now - 1.second)
    expect(item.failed_attempts).to eq(0)
    expect(item.channel).to be_nil
  end

  it "sets the channel attributes" do
    queue.enqueue op: "myop", entity_id: 12, channel: "my-channel"
    item = queue.items.first
    expect(item.channel).to eq("my-channel")
  end
end
