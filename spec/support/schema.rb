__END__

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :unicorns, force: true do |t|
    t.string  :name, null: false
    t.string :affiliation_id
  end

  create_table :foals, force: true do |t|
    t.integer   :parent_id, null: false
    t.string    :nick_name
    t.integer   :age
    t.datetime  :created_at
  end

  create_table :riders, force: true do |t|
    t.string    :nick_name
  end

  create_table :foal_riders, force: true do |t|
    t.integer :rider_id
    t.integer :foal_id
  end

  create_table :pegasus, force: true do |t|
    t.integer   :parent_id, null: false
    t.string    :nick_name
    t.integer   :age
    t.datetime  :created_at
  end

  create_table :mock_product_assets, force: true do |t|
    t.integer   :asset_id
    t.string    :access_level
    t.integer   :product_id
  end

  create_table :mock_group_users, force: true do |t|
    t.integer   :user_id
    t.string    :access_level
    t.integer   :group_id
  end

  create_table :assets, force: true

  create_table :products, force: true

  create_table :users, force: true do |t|
    t.string    :title
  end

  create_table :groupings, force: true

  create_table :manticores, force: true do |t|
    t.string  :dummy_field
  end

  create_table :dragons, force: true do |t|
    t.string  :full_name
  end

  execute "INSERT INTO unicorns(affiliation_id, id, name) VALUES('mpx', 1, 'Faith')"
  execute "INSERT INTO unicorns(affiliation_id, id, name) VALUES('mpx', 2, 'Faery')"
  execute "INSERT INTO unicorns(affiliation_id, id, name) VALUES('mpx', 3, 'Yaser')"

  execute "INSERT INTO foals(id, parent_id, nick_name, age, created_at) VALUES(1, 1, 'Little Faith', 12, 0)"
  execute "INSERT INTO foals(id, parent_id, nick_name, age, created_at) VALUES(2, 1, 'Faith Nick',   9, 0)"

  execute "INSERT INTO riders(id, nick_name) VALUES(1, 'Storm Rider')"
  execute "INSERT INTO riders(id, nick_name) VALUES(2, 'Desert Rider')"

  execute "INSERT INTO foal_riders(rider_id, foal_id) VALUES(1, 1)"
  execute "INSERT INTO foal_riders(rider_id, foal_id) VALUES(2, 1)"

  execute "INSERT INTO pegasus(parent_id, nick_name, age, created_at) VALUES(1, 'Derpy', 12, 0)"

  execute "INSERT INTO dragons(full_name) VALUES('Chrysophylax Dives')"
  execute "INSERT INTO dragons(full_name) VALUES('Nepomuk')"
  execute "INSERT INTO dragons(full_name) VALUES('Smaug')"

  execute "INSERT INTO manticores(dummy_field) VALUES('Dumb Manticore')"

  execute "INSERT INTO users(id, title) VALUES(67, 'sixtyseven')"

  execute "INSERT INTO groupings(id) VALUES(42)"
end
