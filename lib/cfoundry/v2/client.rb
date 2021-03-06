require File.expand_path("../../concerns/login_helpers", __FILE__)
require "forwardable"

module CFoundry::V2
  # The primary API entrypoint. Wraps a BaseClient to provide nicer return
  # values. Initialize with the target and, optionally, an auth token. These
  # are the only two internal states.
  class Client
    include ClientMethods, CFoundry::LoginHelpers
    extend Forwardable

    # Internal BaseClient instance. Normally won't be touching this.
    attr_reader :base

    # [Organization] Currently targeted organization.
    attr_accessor :current_organization

    # [Space] Currently targeted space.
    attr_accessor :current_space

    def_delegators :@base, :target, :target=, :token, :token=,
      :trace, :trace=, :log, :log=, :info

    # Create a new Client for interfacing with the given target.
    #
    # A token may also be provided to skip the login step.
    def initialize(target, token = nil, options = {})
      @base = Base.new(target, token, options)
    end

    def version
      2
    end

    # The currently authenticated user.
    def current_user
      return unless token

      token_data = @base.token.token_data
      if guid = token_data[:user_id]
        user = user(guid)
        user.emails = [{ :value => token_data[:email] }]
        user
      end
    end

    def login(credentials)
      @current_organization = nil
      @current_space = nil
      super
    end

    def register(email, password, options = {})
      uaa_user = @base.uaa.add_user(email, password, options)
      cc_user = user
      cc_user.guid = uaa_user[:id]
      cc_user.create!
      cc_user
    end

    # Clear client token. No requests are made for this.
    def logout
      @base.token = nil
    end

    # Is an authentication token set on the client?
    def logged_in?
      !!@base.token
    end

    def query_target(klass)
      if klass.scoped_space && space = current_space
        space
      elsif klass.scoped_organization && org = current_organization
        org
      else
        self
      end
    end

    def stream_url(url, &blk)
      @base.stream_url(url, &blk)
    end

    def service_instances(opts={})
      opts[:user_provided] = true
      super(opts)
    end

    def service_instances_from(path, *args)
      opts = args.first || {}
      opts[:user_provided] = true
      super(path, opts, *args)
    end

    def make_service_instance(json)
      klass = "CFoundry::V2::#{json[:entity][:type].camelize}".constantize
      klass.new(
        json[:metadata][:guid],
        self,
        json)
    end
  end
end
