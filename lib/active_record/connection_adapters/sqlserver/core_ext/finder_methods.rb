# frozen_string_literal: true

require "active_record/relation"
require "active_record/version"

module ActiveRecord
  module ConnectionAdapters
    module SQLServer
      module CoreExt
        module FinderMethods
          private

          def construct_relation_for_exists(conditions)
            model.with_connection do |connection|
              if connection.sqlserver?
                _construct_relation_for_exists(conditions)
              else
                super
              end
            end
          end

          # Same as original except we order by values in distinct select if present.
          def _construct_relation_for_exists(conditions)
            conditions = sanitize_forbidden_attributes(conditions)

            relation = if distinct_value && offset_value
              # Start of monkey-patch
              if select_values.present?
                order(*select_values).limit!(1)
              else
                except(:order).limit!(1)
              end
              # End of monkey-patch
            else
              except(:select, :distinct, :order)._select!(Arel.sql(::ActiveRecord::FinderMethods::ONE_AS_ONE, retryable: true)).limit!(1)
            end

            case conditions
            when Array, Hash
              relation.where!(conditions) unless conditions.empty?
            else
              relation.where!(primary_key => conditions) unless conditions == :none
            end

            relation
          end
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Relation.include(ActiveRecord::ConnectionAdapters::SQLServer::CoreExt::FinderMethods)
end
