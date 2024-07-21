# frozen_string_literal: true

module ArJdbc
  module Abstract
    module ConnectionManagement
      # @override
      def active?
        super

        return unless @raw_connection

        @raw_connection.active?
      end

      # @override
      def disconnect!
        super # clear_cache! && reset_transaction
        return unless @raw_connection

        @raw_connection.disconnect!
      end

      private

      # @override
      def reconnect
        @raw_connection&.disconnect!

        @raw_connection = nil

        connect
      end

      # @override
      # def verify!(*ignored)
      #  if @connection && @connection.jndi?
      #    # checkout call-back does #reconnect!
      #  else
      #    reconnect! unless active? # super
      #  end
      # end
    end
  end
end
