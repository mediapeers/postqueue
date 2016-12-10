__END__

require 'ostruct'

class MockAssocationInfo < OpenStruct
  def virtual?; mode == :virtual; end
  def belongs_to?; mode == :belongs_to; end
  def habtm?; mode == :has_and_belongs_to_many; end
end

module AnalyticsReflectionStub
  attr :analytics_reflection
  def set_analytics_reflection(hsh)
    @analytics_reflection = OpenStruct.new(hsh)
  end

  attr :analytics_parent
  def set_analytics_parent(analytics_parent)
    @analytics_parent = analytics_parent
  end
end

class Unicorn < ActiveRecord::Base
  extend AnalyticsReflectionStub

  def self.name_without_prefix
    'UnicornWithoutPrefix'
  end

  validates_presence_of :name

  set_analytics_reflection associations_by_foreign_keys: {}, analytics_keys: [:name]
end

class Manticore < ActiveRecord::Base
  def self.name_without_prefix
    'ManticoreWithoutPrefix'
  end
end

class Rider < ActiveRecord::Base
end

class Foal < ActiveRecord::Base
  extend AnalyticsReflectionStub

  belongs_to :parent, class_name: 'Unicorn'
  has_and_belongs_to_many :riders, class_name: 'Rider'

  set_analytics_reflection associations_by_foreign_keys: 
    { 
    parent_id: MockAssocationInfo.new(mode: :belongs_to, klass: Unicorn, name: :parent),
    rider_ids: MockAssocationInfo.new(mode: :has_and_belongs_to_many, klass: Rider, name: :riders),
    stable_ids: MockAssocationInfo.new(mode: :virtual, name: :stables)
  },
  analytics_keys: [:nick_name, :age, :parent]
  set_analytics_parent :parent
end

class Pegasus < ActiveRecord::Base
  extend AnalyticsReflectionStub

  belongs_to :parent, class_name: 'Foal'

  set_analytics_reflection associations_by_foreign_keys: { :parent_id => OpenStruct.new(klass: Foal, name: :parent) },
    analytics_keys: [:nick_name, :age, :parent]
  set_analytics_parent :parent

  attr_reader :affiliation_id
end

class Dragon < ActiveRecord::Base
  def self.name_without_prefix
    'DragonWithoutPrefix'
  end

  def describe
    'yihaa'
  end

  extend AnalyticsReflectionStub
end

class Asset < ActiveRecord::Base
  extend AnalyticsReflectionStub
  attr_reader :affiliation_id
end

class Product < ActiveRecord::Base
  extend AnalyticsReflectionStub
  attr_reader :affiliation_id
end

class User < ActiveRecord::Base
  extend AnalyticsReflectionStub
  attr_reader :affiliation_id

  def analytics_title
    "my analytics_title"
  end
end

class Grouping < ActiveRecord::Base
  extend AnalyticsReflectionStub
  attr_reader :affiliation_id
end

class Group < Grouping
end

class MockProductAsset < ActiveRecord::Base
  has_one :asset
  has_one :product

  attr_accessor :asset, :product
end

class MockGroupUser < ActiveRecord::Base
  has_one :group
  has_one :user

  attr_accessor :group, :user
end
