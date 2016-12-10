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
queue.enqueue op: "myop", entity_type: "mytype", entity_id: 12
queue.process do |op, entity_type, entity_ids|
  # note: entity_ids is always an Array of ids.
  case "#{op}/#{entity_type}"
  when "reindex/product"
    Product.index_many(Product.where(id: entity_ids))
  else
    raise "Unsupported op/entity_type: #{op}/#{entity_type}"
  end
end
```

The callback will receive the `op` and `entity_type` attributes and the `entity_ids` of all queue entries
selected for processing. If the block fails, by either returning `false` or by raising an exception the
queue entries are postponed a bit, up until `Postqueue::MAX_ATTEMPTS` times (which currently is defined as 5).

The method will return the return value of the block. 

If no callback is given the return value will be the `[op, entity_type, entity_ids]` values that would have
been sent to the block. This is highly unrecommended though, since when using a block to do processing errors
and exceptions can properly be dealt with.

Postqueue.process also accepts the following arguments:

- `entity_type`: only process entries with this `entity_type`;
- `op`: only process entries with this `op` value;
- `batch_size`: when the first matching entry supports batch processing limit the size of the batch to the bassed in size.

Example:

    Postqueue.process(entity_type: 'Product', batch_size: 10) do |op, entity_type, entity_ids|
      # only handle Product entries
    end

If the queue is empty or no matching queue entry could be found, both `Postqueue.process` and `Postqueue.process_one` will return nil.

### process a single entry

For the simple just-give-me-the-next use case there is a shortcut, which only processed the first matching entry. Under the hood this calls Postqueue.process with `batch_size` set to `1`.

    Postqueue.process_one do |op, entity_type, entity_ids|
    end

Note that even though `process_one` will only ever process a single entry the `entity_ids` parameter to the block is still an array (holding a single ID in that case).

## idempotent operations

If queue items represent idempotent operations they need not be run repeatedly, but only once. To implement idempotent
operations, subclass `Postqueue::Base` and reimplement the `idempotent?` method. The following marks all "reindex" 
ops as idempotent:

    class Testqueue < Postqueue::Base
      def idempotent?(entity_type:,op:)
        op == "reindex"
      end
    end

## batch processing

Often queue items can be processed in batches for a better performance of the entire system. To enable
batch processing for some items subclass `Postqueue::Base` and reimplement the `batch_size?` method
to return a suggested batch_size for a specific operation. The following implements a batch_size of 100
for all queue entries: 

    class Testqueue < Postqueue::Base
      def batch_size(entity_type:,op:)
        100
      end
    end

## Searchable via SQL

In contrast to other queue implementations available for Rubyists this queue formats entries in a way that
makes it possible to query the queue via SQL. On the other hand this queue also does not allow to 
enqueue arbitrary entries as these others do.

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

