# Postqueue

The postqueue gem implements a simple to use queue on top of postgresql. Since this implementation is using the SKIP LOCKED
syntax, it needs PostgresQL >= 9.5.

Why not using another queue implementation? postqueue comes with some extras:

- support for optimal handling of idempotent operations 
- batch processing
- searchable via SQL

## Basic usage

```ruby
queue = PostgresQL::Base.new
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
of all queue entries selected for processing. The `processing` method will return the 
return value of the block.

If no callback is given the return value will be the `[op, entity_ids]` values
that would have been sent to the block. This is highly unrecommended though, since 
when using a block to do processing errors and exceptions can properly be dealt with.

Postqueue.process also accepts the following arguments:

- `op`: only process entries with this `op` value;
- `batch_size`: maximum number of items to process in one go.

Example:

    Postqueue.process(op: 'product/reindex', batch_size: 10) do |op, entity_ids|
      # only handle up to 10 "product/reindex" entries
    end

If the block fails, by either returning `false` or by raising an exception the queue will
postpone processing these entries by an increasing amount of time, up until 
`Postqueue::MAX_ATTEMPTS` failed attempts. The current MAX_ATTEMPTS definition
leads to a maximum postpone interval (currently up to 190 seconds).

If the queue is empty or no matching queue entry could be found, `Postqueue.process` 
returns nil.

### process a single entry

Postqueue implements a shortcut to process only a single entry. Under the hood this 
calls `Postqueue.process` with `batch_size` set to `1`:

    Postqueue.process_one do |op, entity_ids|
    end

Note that even though `process_one` will only ever process a single entry the 
`entity_ids` parameter to the block is still an array (holding a single ID 
in that case).

## idempotent operations

Postqueue comes with simple support for idempotent operations: if an operation is deemed
idempotent it is not enqueued again if it can be found in the queue already. Note that 
a queue item will be created if another item is currently being processed.

    class Testqueue < Postqueue::Base
      def idempotent?(entity_type:,op:)
        op == "reindex"
      end
    end

## batch processing

Often queue items can be processed in batches for a better performance of the entire system. 
To allow batch processing for some items subclass `Postqueue::Base` and reimplement the 
`batch_size?` method to return a suggested batch size for a specific operation. 
The following implements a batch_size of 100 for all queue entries: 

    class Batchqueue < Postqueue::Base
      def batch_size(op:)
        100
      end
    end

## Searchable via SQL

In contrast to other queue implementations available for Rubyists this queue formats
entries in a way that makes it possible to query the queue via SQL. On the other 
hand this queue also does not allow to enqueue arbitrary entries as these others do.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'postqueue'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install postqueue

## Usage

## Development

After checking out the repo, run `bin/setup` to install dependencies. Make sure you have a local postgresql implementation of
at least version 9.5. Add a `postqueue` user with a `postqueue` password, and create a `postqueue_test` database for it. 
The script `./scripts/prepare_pg` can be helpful in establishing that.

Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. 

To release a new version, run `./scripts/release`, which will bump the version number, create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/postqueue.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

