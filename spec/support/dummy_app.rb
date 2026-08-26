# frozen_string_literal: true

ENV["HANAMI_ENV"] ||= "test"

require_relative "../dummy_app/config/app"

Hanami.boot
