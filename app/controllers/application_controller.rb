class ApplicationController < ActionController::Base
  class Suspense
    attr_accessor :promises

    def initialize(render)
      @promises = Thread::Queue.new
      @renderer = render
    end

    def render_to_string(**cfg)
      @renderer.render_to_string(**cfg)
    end

    def finalize!(stream)
      write_all stream
    ensure
      stream.close
    end

    private

    def write_all(stream)
      while @promises.size > 0
        promise = @promises.pop
        stream.write promise.value
      end
    end
  end

  module Suspending
    extend ActiveSupport::Concern

    included do
      include ActionController::Live

      def suspense
        @suspense ||= Suspense.new(self)
      end

      after_action do
        @suspense&.finalize!(response.stream)
      end
    end
  end
end
