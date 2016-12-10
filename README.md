# Postqueue

The postqueue gem implements a simple to use queue on top of postgresql. Since this implementation is using the SKIP LOCKED
syntax, it needs PostgresQL >= 9.5.

Why not using another queue implementation? postqueue comes with some extras:

- automatic removal of duplicates
- batch processing
- searchable via SQL

## Automatically remove duplicates

Each entry consists of the following attributes only (apart from attributes needed for internal managing queue items)

- `entity_type`, `entity_id`: These entries describe the item on which to run an operation from.
- `op`: this entry describes the operation to run. 

Using the `skip_duplicates` option, postqueue processing removes duplicate entries on the queue. That means that as soon 
as a certain `[ entity_type, entity_id, op ]` combination has been processed successfully, duplicates of these will also
be removed from the queue.

## Batch processing

If you have multiple entries with the same `op` and `entity_type`, but different `entity_id`, they might 
implement the same operation on a set of different objects of the same type. When processing these entries
it might be possible to provide an optimized implementation for these.

Example:

    Postqueue.process limit: 100, skip_duplicates: true do |op, entity_type, entity_ids|
      case "#{op}/#{entity_type}"
      when "reindex/product"
        Product.index_many(Product.where(id: entity_ids))
      else
        raise "Unsupported op/entity_type: #{op}/#{entity_type}"
      end
    end

## the queue is structured so that it can be searched via SQL

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

### enqueuing an entry

    Postqueue.enqueue op: "myop", entity_type: "mytype", entity_id: 12

### processing entries

    Postqueue.process do |op, entity_type, entity_ids|
    end

The callback will receive the `op` and `entity_type` attributes and the `entity_ids` of all queue entries
selected for processing. If the block fails, by either returning `false` or by raising an exception the
queue entries are postponed a bit, up until `Postqueue::MAX_ATTEMPS` times (which currently is defined as 3).

The method will return the return value of the block. 

If no callback is given the return value will be the `[op, entity_type, entity_ids]` values that would have
been sent to the block. This is highly unrecommended though, since when using a block to do processing errors
and exceptions can properly be dealt with.

Postqueue.process also accepts a number of arguments:

- limit: limits the number of queue items to process. Default: 100;
- where: add additional search conditions, Default: none;
- skip_duplicates: when set to false do not remove all duplicates of processed entries from the queue. Default: true

Example:

    Postqueue.process({where: {entity_type: 'Product'}, limit: 10, skip_duplicates: false) do |op, entity_type, entity_ids|
    end

For the simple just-give-me-the-next use case there is a shortcut, which only processed the first matching entry. Under the hood this calls Postqueue.process with `limit` set to `1` and `skip_duplicates` set to `false`

    Postqueue.process_one do |op, entity_type, entity_ids|
    end

Note that even though `post_process_one` will only ever process a single entry the `entity_ids` parameter to the block is still an array (holding a single ID in that case).

Note that If the queue is empty or no matching queue entry could be found, both `Postqueue.process` and `Postqueue.process_one` will return nil.
 
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

