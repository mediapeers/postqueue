module Postqueue
  # The Postqueue::Notifications module manages notifications. This allows
  # runners to sleep until explicitely woken up.
  module Notifications
    extend self

    CHANNEL = "postqueue"
    DEFAULT_WAIT_TIME = 120

    # Waits for an incoming notification on CHANNEL. If no notifications
    # arrive within \a timeout seconds, returns +false+. If notifications
    # arrive it will flush all notifications and return +true+.
    def wait!(timeout: DEFAULT_WAIT_TIME)
      start_listening

      unless Simple::SQL.wait_for_notify(timeout)
        return false
      end

      # flush notifications: if we have a flurry of activity we might end
      # up with a larger number of notifications. We don't want them in the
      # inbox any more - therefore we flush them.
      :nop while Simple::SQL.wait_for_notify(0.000001)

      true
    end

    def notify!
      Simple::SQL.ask "NOTIFY #{CHANNEL}"
    end

    private

    def start_listening
      return if @is_listening

      Postqueue.logger.info "LISTEN to pg channel #{CHANNEL}"
      Simple::SQL.ask "LISTEN #{CHANNEL}"
      @is_listening = true
    end
  end
end
