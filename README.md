# Postqueue

## Intro

The postqueue gem implements a simple to use queue on top of postgresql. 

Lets have a word about words first: while a queue like this is typically used in a job queueing scenario, this document does not talk about jobs, it talks about **queue items**; it also does not schedule a job, it **enqueues** an item, and it does not executes a job, it **processes** queue items.

So, why building an additional queue implementation? Compared to the usual suspects this is what postqueue brings to the table:

- The **item structure** is intentionally kept very **simple**: an item is described by an `op` field - a string - and an `id` field, an integer. In a typical usecase a queue item would describe an operation on a specific entity, and `op` would name both the operation and the entity type (say: `"product/invalidate"`) and the `id` field would hold the id of the product to invalidate.

- Such a simplistic item structure lends quite well to **querying** the queue **using SQL**. While this is great for monitoring purposes - it is quite easy to fetch metrics regarding upcoming items - it also allows special handling of idempotent operations and automatic batching.

- Some tasks typically handled by queues are of **idempotent** nature. For example, reindexing a document into a NoSQL search index needs not be done twice in a row, since only the last change to the primary object should and ultimately will be stored in the search index. Such tasks can therefore be run only once. postqueue supports this feature by optionally skipping duplicates when enqueuing tasks.

- Other tasks can be handled much more efficient when **run in batches**. Typical examples include processing a larger number of entities that need to be read from a database, but could be pulled much more efficient in a single query instead of in N queries. postqueue automatically batches such items.

- Being based on Postgresql postqueue provides **transactional semantics**: an item written into the database in a transaction that fails afterwards is never processed.

- **automatic retries**: like delayed job postqueue implements a rudimentary form of error processing. A failing item - this is an item which does not have a handler registered, or whose handler fails by raising an exception - is kept in the queue and reprocessed later. It is reprocessed up to N times (currently 5 times by default) until it is "doomed" ultimately. This is similar to delayed job's error handling, with some differences, however: 

  - no backtrace is kept in the database
  - the waiting time doesn't ramp up as fast (postqueue does `1.5 ** <number of retries>`)

Please be aware that postqueue is using the `SELECT .. FOR UPDATE SKIP LOCKED` Postgresql syntax, and therefore needs at least PostgresQL >= 9.5.

## Basic usage

Postqueue is able to run queues that use separate tables as their backstore, or use a preexisting table. However, basic usage should cover most scenarios. 

Hence we cover the basic scenario here: in that scenario a single table *"postqueue"* is used to store queue items, and the `Postqueue` default queue holds all configuration. We also assume that you want to integrate Postqueue with a Rails application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'postqueue'
```

And then execute:

    $ bundle

### Adding a migration

The following migration creates a postqueue table with all necessary entries:

```ruby
class AddPostqueue < ActiveRecord::Migration
  def up
    Postqueue.migrate!
  end

  def down
    Postqueue.unmigrate!
  end
end
```

### Configuring Postqueue

The postqueue configuration descrives all possible operations and their features:

- is it possible to batch these operationss? In that case multiple queue items will be combined and processed in one go. Set `batch_size:` to a sensible size.
- is this an idempotent operation? Set `idempotent:` to true.

The configuration file should live in `config/initializer/postqueue.rb` for Rails apps, and in `config/postqueue.rb` in other Ruby applications.

```ruby
# config/initializer/postqueue.rb
Postqueue.on "refresh", batch_size: 10, idempotent: true do |op, entity_ids|
  Product.index_many(Product.where(id: entity_ids))
end
```

Note that you could define an operation without a handler callback:

```ruby
Postqueue.on "foo"
```

In this case the `foo` ops are just removed from the queue during procesing.

### Postqueue database configuration

When run from inside a Rails application Postqueue will reuse the applications database connection. When run outside a Rails application postqueue will use a
`config/database.yml` file to determine database connection settings. It will use the `RAILS_ENV` environment value, defaulting to `"development"`, to choose from entries in that file.

### Enqueueing items

Enqueuing items can be done using code like this:

```ruby
# enqueue a single op
Postqueue.enqueue op: "refresh", entity_id: 12

# enqueue multiple ops in one go.
Postqueue.enqueue op: "refresh", entity_id: [12,13]
Postqueue.enqueue op: "refresh", entity_id: [13,14]
```

Note that enqueueing is pretty fast. My developer machine is able to enqueue ~20000 items per second.

### Processing items

While we recommend to use the command line interface to process postqueue items you can certainly process these *from within ruby code* by using one of these methods:

    # process the next batch of items
    Postqueue.process
    
    # process a single item, do not batch
    Postqueue.process_one
    
    # process batches of items until there are none left
    Postqueue.process_until_empty

These calls will select a one or more queue items for processing (with the same `op` attribute). The `process_*` methods will then call the callback for that operation with the `entity_ids` of all queue entries. After processing they will return the number of processed items, or 0 if no items could be found or be processed.

The `process_*` methods also accept the following arguments:

- `op`: only process entries with this `op` value;
- `batch_size`: maximum number of items to process in one go.

Example:

    # process only `product` queue items
    Postqueue.process(op: 'product', batch_size: 10)

### processing from the command line

```ruby
bundle exec postqueue run
```

starts a single postqueue runner. Note that there is intentionally no option to daemonize this process or to run these in parallel.

The postqueue CLI has additional commands, see below.

## The postqueue CLI

postqueue comes with a command line interface:

```
~/postqueue[master] > ./bin/postqueue --help
This is postqueue 0.5.3. Usage examples:

  postqueue [ stats ]
  postqueue peek
  postqueue enqueue op entity_id,entity_id,entity_id
  postqueue run
  postqueue help
  postqueue process
```

You can use the postqueue CLI to

- enqueue an item, e.g. `bundle exec postqueue enqueue foo 1,2,3`
- start a runner to process the queue: `bundle exec postqueue run`
- process a single item off the queue: `bundle exec postqueue process`
- get some stats for the queue: `bundle exec postqueue stats`
- get a list of the next 100 queue items: `bundle exec postqueue peek`

## Additional  notes

### Concurrency

Postqueue implements the following concurrency guarantees:

- catastrophic DB failure and communication breakdown aside a queue item which is enqueued will eventually be processed successfully exactly once;
- multiple consumers can work in parallel.

Note that you should not share a Postqueue instance across threads - instead you should create process objects with the identical configuration.

### Idempotent operations

If an operation was configured as idempotent (using the `Postqueue.on "op", idempotent: true` configuration) duplicate idempotent operations are not enqueued. However, if multiple transactions are enqueueing items at the same time, or when an idempotent item is processing while another item is being enqueued an additional queue item will still be enqueued. Therefore we also remove duplicate items during processing.

### Using non-default tables or databases

To use a non-default table or a non-default database, change the `item_class`
attribute of the queue:

    Postqueue.new do |queue|
      queue.item_class = MyItemClass
    end

`MyItemClass` should inherit from Postqueue::Item and use the same or a compatible database structure.

### Special Ops

Postqueue always registers the following operations:

- `"test"` will write an output to the Postqueue.logger. Use this to test your infrastructure.
- `"fail"` will always raise an exception. Use this to test your error handling integration.

### Unknown operations

You can define a handler to handle unknown operations like this:

    on :missing_handler do |op, entity_ids|
      raise MissingHandler, queue: self, op: op, entity_ids: entity_ids
    end

### Exception handling

You can define a handler to handle any exceptions. This is the integration point for your exception handling framework like rollbar.com or so.

The default exception handler is:

    Postqueue.on_exception do |e, _, _|
      e.send :raise
    end

The following would report exceptions to STDOUT and to rollbar:

    Postqueue.on_exception do |e, op, entity_ids|
      msg =  "Caught error #{e.to_s.inspect}"
      msg += " on op: #{op.inspect} "
      msg += " w/entity_ids: #{entity_ids.inspect}"
      Rollbar.error(e)
    end

## Testing postqueue applications

Postqueue works usually in an async mode: queue items that are enqueued are kept in a queue, and must be picked up later explicitely for processing (via one of the `process`, `process_one` or `process_until_empty` methods).

During unit tests it is likely preferrable to process queue items synchronously - if you are interested in actual processing - or, at least, in a mode which validates that the `op` value is actually configured in your application (i.e. that a handler is registered for that op). You can change the processing mode via

    # can be :sync, :async, :verify
    Postqueue.processing = :sync

## Development

After checking out the repo, run `bin/setup` to install dependencies. Make sure you have a local postgresql implementation of at least version 9.5. Add a `postqueue` user with a `postqueue` password, and create a `postqueue_test` database for it. The script `./scripts/prepare_pg` can be somewhat helpful in establishing that.

Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. 

To release a new version, run `./scripts/release`, which will bump the version number, create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/postqueue.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

