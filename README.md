# Postqueue

## Intro

The postqueue gem implements a simple to use queue on top of postgresql. Note that while 
a queue like this is typically used in a job queueing scenario, this document does not 
talk about jobs, it talks about **queue items**; it also does not schedule a job, 
it **enqueues** an item, and it does not executes a job, it **processes** queue items.

Why building an additional queue implementation? Compared to delayed_job or the other 
usual suspects postqueue implements these features:

- The item structure is intentionally kept super simple: an item is described by an
  `op` field - a string - and an `id` field, an integer. In a typical usecase a 
  queue item would describe an operation on a specific entity, where `op` names 
  both the operation and the entity type and the `id` field would describe the 
  individual entity.

- With such a simplistic item structure the queue itself can be searched or 
  otherwise evaluated using SQL. This also allows for **skipping duplicate entries** 
  when enqueuing items (managed via a duplicate: argument when enqueuing) and for 
  **batch processing** multple items in one go. 

- With data being kept in a Postgresql database processing provides **transactional semantics**: 
  an item failing to process stays in the queue. Error handling is kept simpe to a 
  strategy of rescheduling items up to a specific maximum number of processing attemps.

Please be aware that postqueue is using the SELECT .. FOR UPDATE SKIP LOCKED Postgresql syntax, 
and therefore needs at least PostgresQL >= 9.5.

## Basic usage

```ruby
queue = Postqueue.new
queue.enqueue op: "product/reindex", entity_id: [12,13,14,15]
queue.process do |op, entity_ids|
  # note: entity_ids is always an Array of ids.
  case op
  when "product/reindex"
    Product.index_many(Product.where(id: entity_ids))
  else
    raise "Unsupported op: #{op}"
  end
end
```

The process call will select a number of queue items for processing. They will all have 
the same `op` attribute. The callback will receive the `op` attribute and the `entity_ids`
of all queue entries selected for processing. The `processing` method will return the number
of processed items.

If no callback is given the matching items are only removed from the queue without
any processing.

Postqueue.process also accepts the following arguments:

- `op`: only process entries with this `op` value;
- `batch_size`: maximum number of items to process in one go.

Example:

    Postqueue.process(op: 'product/reindex', batch_size: 10) do |op, entity_ids|
      # only handle up to 10 "product/reindex" entries
    end

If the block raises an exception the queue will postpone processing these entries 
by an increasing amount of time, up until `queue.max_attempts` failed attempts.
That value defaults to 5.

If the queue is empty or no matching queue entry could be found, `Postqueue.process` 
returns 0.

## Advanced usage

### Concurrency

Postqueue implements the following concurrency guarantees:

- catastrophic DB failure and communication breakdown aside a queue item which is enqueued will eventually be processed successfully exactly once;
- multiple consumers can work in parallel.

Note that you should not share a Postqueue ruby object across threads - instead you should create
process objects with the identical configuration.

### Idempotent operations

When enqueueing items duplicate idempotent operations are not enqueued. Whether or not an operation
should be considered idempotent is defined when configuring the queue:

     Postqueue.new do |queue|
       queue.idempotent_operation "idempotent"
     end

### Processing a single entry

Postqueue implements a shortcut to process only a single entry. Under the hood this 
calls `Postqueue.process` with `batch_size` set to `1`:

    queue.process_one

Note that even though `process_one` will only ever process a single entry the 
`entity_ids` parameter to the callback is still an array (with a single ID entry 
in that case).

### Migrating

Postqueue comes with migration helpers:

    # set up a table for use with postqueue.
    Postqueue.migrate!(table_name = "postqueue")

    # set up a table for use with postqueue.
    Postqueue.unmigrate!(table_name = "postqueue")

You can also set up your own table, as long as it is compatible.

To use a non-default table or a non-default database, change the `item_class`
attribute of the queue:

    Postqueue.new do |queue|
      queue.item_class = MyItemClass
    end

`MyItemClass` should inherit from Postqueue::Item and use the same or a compatible database
structure.

## Batch processing

Often queue items can be batched together for a performant operation. To allow batch 
processing for some items, configure the Postqueue to either set a `default_batch_size`
or an operation-specific batch_size:

    Postqueue.new do |queue|
      queue.default_batch_size = 100
      queue.batch_sizes["batchable"] = 10
    end

## Test mode

During unit tests it is likely preferrable to process queue items in synchronous fashion (i.e. as they come in).
You can enable this mode via:

    Postqueue.async_processing = false

You can also enable this on a queue-by-queue base via:

    Postqueue.new do |queue|
      queue.async_processing = false
    end

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'postqueue'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install postqueue

## Development

After checking out the repo, run `bin/setup` to install dependencies. Make sure you have 
a local postgresql implementation of at least version 9.5. Add a `postqueue` user with 
a `postqueue` password, and create a `postqueue_test` database for it. The script 
`./scripts/prepare_pg` can be somewhat helpful in establishing that.

Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. 

To release a new version, run `./scripts/release`, which will bump the version number, 
create a git tag for the version, push git commits and tags, and push the `.gem` file 
to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/postqueue.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

