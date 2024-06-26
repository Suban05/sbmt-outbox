# frozen_string_literal: true

require "sbmt/outbox/metrics/utils"

module Sbmt
  module Outbox
    module V2
      module Tasks
        class Base
          attr_reader :item_class, :worker_name, :worker_version, :log_tags, :yabeda_labels

          delegate :owner, to: :item_class

          def initialize(item_class:, worker_name:, worker_version: 2)
            @item_class = item_class
            @worker_name = worker_name
            @worker_version = worker_version

            @log_tags = {
              box_type: item_class.box_type,
              box_name: item_class.box_name,
              worker_name: worker_name,
              worker_version: worker_version
            }

            @yabeda_labels = {
              type: item_class.box_type,
              name: Sbmt::Outbox::Metrics::Utils.metric_safe(item_class.box_name),
              owner: owner,
              worker_version: 2,
              worker_name: worker_name
            }
          end

          def to_h
            result = {}
            instance_variables.each do |iv|
              iv = iv.to_s[1..]
              result[iv.to_sym] = instance_variable_get(:"@#{iv}")
            end
            result
          end
        end
      end
    end
  end
end
