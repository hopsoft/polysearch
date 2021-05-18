# frozen_string_literal: true

require_relative "polysearch/version"
require_relative "../app/models/record"
require_relative "../app/models/concerns/searchable"

module Polysearch
  class Engine < Rails::Engine
  end
end
