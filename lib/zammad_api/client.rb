require 'forwardable'

require 'zammad_api/log'
require 'zammad_api/transport'
require 'zammad_api/dispatcher'
require 'zammad_api/resources'

module ZammadAPI

  class Client
    extend Forwardable

    def_delegators :@transport, :on_behalf_of, :on_behalf_of=

    def initialize(config)
      @config    = config
      @logger    = ZammadAPI::Log.new(@config)
      @transport = ZammadAPI::Transport.new(@config, @logger)
      check_config
    end

    def perform_on_behalf_of(identifier)
      self.on_behalf_of = identifier
      yield.tap do |_|
        self.on_behalf_of = nil
      end
    end

    def method_missing(method, *_args)
      method     = modulize( method.to_s )
      class_name = "ZammadAPI::Resources::#{method}"
      begin
        class_object = Kernel.const_get(class_name)
      rescue
        raise "Resource for #{method} does not exist"
      end
      ZammadAPI::Dispatcher.new(@transport, class_object)
    end

    private

    def check_config
      raise 'missing url in config' if !@config[:url]
      raise 'config url needs to start with http:// or https://' if @config[:url] !~ %r{^(http|https)://}

      # check for token auth
      return if @config[:http_token] && !@config[:http_token].empty?
      return if @config[:oauth2_token] && !@config[:oauth2_token].empty?

      if !@config[:user] || @config[:user].empty?
        raise 'missing user in config'
      end

      return if @config[:password] && !@config[:password].empty?

      raise 'missing password in config'
    end

    def modulize(string)
      string.gsub(/__(.?)/) { "::#{$1.upcase}" }
            .gsub(%r{/(.?)}) { "::#{$1.upcase}" }
            .gsub(/(?:_+|-+)([a-z])/) { $1.upcase }
            .gsub(/(\A|\s)([a-z])/) { $1 + $2.upcase }
    end
  end
end
