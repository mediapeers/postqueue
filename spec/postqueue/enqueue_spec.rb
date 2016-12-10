require 'spec_helper'

describe 'enqueuing' do
  let(:queue) { Postqueue.new }

  before do
    queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
  end

  let(:item) { Postqueue::Item.first }

  it 'enqueues items' do
    expect(item.op).to eq("myop")
    expect(item.entity_type).to eq("mytype")
    expect(item.entity_id).to eq(12)
  end

  it 'sets defaults' do
    expect(item.created_at).to be > (Time.now - 1.second)
    expect(item.next_run_at).to be > (Time.now - 1.second)
    expect(item.failed_attempts).to eq(0)
  end
end
