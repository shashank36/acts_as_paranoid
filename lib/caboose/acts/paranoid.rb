module Caboose #:nodoc:
  module Acts #:nodoc:
    # Overrides some basic methods for the current model so that calling #destroy sets a 'deleted_at' field to the current timestamp.
    # This assumes the table has a deleted_at date/time field.  Most normal model operations will work, but there will be some oddities.
    #
    #   class Widget < ActiveRecord::Base
    #     acts_as_paranoid
    #   end
    #
    #   Widget.find(:all)
    #   # SELECT * FROM widgets WHERE widgets.deleted_at IS NULL
    #
    #   Widget.find(:first, :conditions => ['title = ?', 'test'], :order => 'title')
    #   # SELECT * FROM widgets WHERE widgets.deleted_at IS NULL AND title = 'test' ORDER BY title LIMIT 1
    #
    #   Widget.find_with_deleted(:all)
    #   # SELECT * FROM widgets
    #
    #   Widget.find(:all, :with_deleted => true)
    #   # SELECT * FROM widgets
    #
    #   Widget.count
    #   # SELECT COUNT(*) FROM widgets WHERE widgets.deleted_at IS NULL
    #
    #   Widget.count ['title = ?', 'test']
    #   # SELECT COUNT(*) FROM widgets WHERE widgets.deleted_at IS NULL AND title = 'test'
    #
    #   Widget.count_with_deleted
    #   # SELECT COUNT(*) FROM widgets
    #
    #   @widget.destroy
    #   # UPDATE widgets SET deleted_at = '2005-09-17 17:46:36' WHERE id = 1
    #
    #   @widget.destroy!
    #   # DELETE FROM widgets WHERE id = 1
    # 
    module Paranoid
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_paranoid
          unless paranoid? # don't let AR call this twice
            alias_method :destroy_without_callbacks!, :destroy_without_callbacks
            class << self
              alias_method :find_with_deleted,  :find
              alias_method :count_with_deleted, :count
            end
          end
          include InstanceMethods
        end

        def paranoid?
          self.included_modules.include?(InstanceMethods)
        end
      end

      module InstanceMethods #:nodoc:
        def self.included(base) # :nodoc:
          base.extend ClassMethods
        end

        module ClassMethods
          def find(*args)
            with_deleted_scope { find_with_deleted(*args) }
          end

          def count(*args)
            with_deleted_scope { count_with_deleted(*args) }
          end

          protected
            def with_deleted_scope(&block)
              with_scope({:find => { :conditions => "#{table_name}.deleted_at IS NULL" } }, :merge, &block)
            end
        end

        def destroy_without_callbacks
          unless new_record?
            now = self.class.default_timezone == :utc ? Time.now.utc : Time.now
            self.class.update_all self.class.send(:sanitize_sql, ["deleted_at = ?", now]), "id = #{quote(id)}"
          end
          freeze
        end

        def destroy_with_callbacks!
          return false if callback(:before_destroy) == false
          result = destroy_without_callbacks!
          callback(:after_destroy)
          result
        end

        def destroy!
          transaction { destroy_with_callbacks! }
        end
      end
    end
  end
end