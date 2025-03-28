# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLServer
      module Quoting
        extend ActiveSupport::Concern

        QUOTED_COLUMN_NAMES = Concurrent::Map.new # :nodoc:
        QUOTED_TABLE_NAMES = Concurrent::Map.new # :nodoc:

        module ClassMethods
          def column_name_matcher
            /
              \A
              (
                (?:
                  # [database_name].[database_owner].[table_name].[column_name] | function(one or no argument)
                  ((?:\w+\.|\[\w+\]\.)?(?:\w+\.|\[\w+\]\.)?(?:\w+\.|\[\w+\]\.)?(?:\w+|\[\w+\]) | \w+\((?:|\g<2>)\))
                )
                (?:\s+AS\s+(?:\w+|\[\w+\]))?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def column_name_with_order_matcher
            /
              \A
              (
                (?:
                  # [database_name].[database_owner].[table_name].[column_name] | function(one or no argument)
                  ((?:\w+\.|\[\w+\]\.)?(?:\w+\.|\[\w+\]\.)?(?:\w+\.|\[\w+\]\.)?(?:\w+|\[\w+\]) | \w+\((?:|\g<2>)\))
                )
                (?:\s+COLLATE\s+\w+)?
                (?:\s+ASC|\s+DESC)?
                (?:\s+NULLS\s+(?:FIRST|LAST))?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def quote_column_name(name)
            QUOTED_COLUMN_NAMES[name] ||= SQLServer::Utils.extract_identifiers(name).quoted
          end

          def quote_table_name(name)
            QUOTED_TABLE_NAMES[name] ||= SQLServer::Utils.extract_identifiers(name).quoted
          end
        end

        def fetch_type_metadata(sql_type, sqlserver_options = {})
          cast_type = lookup_cast_type(sql_type)

          simple_type = SqlTypeMetadata.new(
            sql_type: sql_type,
            type: cast_type.type,
            limit: cast_type.limit,
            precision: cast_type.precision,
            scale: cast_type.scale
          )

          SQLServer::TypeMetadata.new(simple_type, **sqlserver_options)
        end

        def quote_string(s)
          SQLServer::Utils.quote_string(s)
        end

        def quote_string_single(s)
          SQLServer::Utils.quote_string_single(s)
        end

        def quote_string_single_national(s)
          SQLServer::Utils.quote_string_single_national(s)
        end

        def quote_default_expression(value, column)
          cast_type = lookup_cast_type(column.sql_type)
          if cast_type.type == :uuid && value.is_a?(String) && value.include?("()")
            value
          else
            super
          end
        end

        def quoted_true
          "1"
        end

        def unquoted_true
          1
        end

        def quoted_false
          "0"
        end

        def unquoted_false
          0
        end

        def quoted_date(value)
          if value.acts_like?(:time)
            Type::DateTime.new.serialize(value)
          elsif value.acts_like?(:date)
            Type::Date.new.serialize(value)
          else
            value
          end
        end

        def quote(value)
          case value
          when Type::Binary::Data
            "0x#{value.hex}"
          when ActiveRecord::Type::SQLServer::Data
            value.quoted
          when String, ActiveSupport::Multibyte::Chars
            "N#{super}"
          else
            super
          end
        end

        def type_cast(value)
          case value
          when ActiveRecord::Type::SQLServer::Data
            value.to_s
          else
            super
          end
        end
      end
    end
  end
end
