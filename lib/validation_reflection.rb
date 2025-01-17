require 'ostruct'

module ValidationReflection # :nodoc:

  extend self

  CORE_VALIDATONS = [
     :validates_acceptance_of,
     :validates_associated,
     :validates_confirmation_of,
     :validates_exclusion_of,
     :validates_format_of,
     :validates_inclusion_of,
     :validates_length_of,
     :validates_numericality_of,
     :validates_presence_of,
     :validates_uniqueness_of,
   ].freeze
   
  @@reflected_validations = CORE_VALIDATONS.dup
  
  @@in_ignored_subvalidation = false

  mattr_accessor  :reflected_validations,
                  :in_ignored_subvalidation

  def included(base) # :nodoc:
    return if base.kind_of?(::ValidationReflection::ClassMethods)
    base.extend(ClassMethods)
  end

  # Iterate through all validations and store/cache the info
  # for later easy access.
  #
  def install(base)
    @@reflected_validations.each do |validation_type|
      next if base.respond_to?(:"#{validation_type}_with_reflection")
      ignore_subvalidations = false
      
      if validation_type.kind_of?(::Hash)
        ignore_subvalidations = validation_type[:ignore_subvalidations]
        validation_type = validation_type[:method]
      end
      
      base.class_eval %{
        class << self
          def #{validation_type}_with_reflection(*attr_names)
            ignoring_subvalidations(#{ignore_subvalidations}) do
              #{validation_type}_without_reflection(*attr_names)
              remember_validation_metadata(:#{validation_type}, *attr_names)
            end
          end
          alias_method_chain :#{validation_type}, :reflection
        end
      }, __FILE__, __LINE__
    end
  end

  module ClassMethods

    include ::ValidationReflection

    # Returns an array of MacroReflection objects for all validations in the class
    def reflect_on_all_validations
      self.reflected_validations || []
    end

    # Returns an array of MacroReflection objects for all validations defined for the field +attr_name+.
    def reflect_on_validations_for(attr_name)
      self.reflect_on_all_validations.select do |reflection|
        reflection.name == attr_name.to_sym
      end
    end

    private

      # Store validation info for easy and fast access.
      #
      def remember_validation_metadata(validation_type, *attr_names)
        configuration = attr_names.last.is_a?(::Hash) ? attr_names.pop : {}
        attr_names.flatten.each do |attr_name|
          class_attribute :reflected_validations
          self.reflected_validations = [::ActiveRecord::Reflection::MacroReflection.new(validation_type, attr_name.to_sym, configuration, self)]
        end
      end

      def ignoring_subvalidations(ignore)
        save_ignore = self.in_ignored_subvalidation
        unless self.in_ignored_subvalidation
          self.in_ignored_subvalidation = ignore
          yield
        end
      ensure
        self.in_ignored_subvalidation = save_ignore
      end
  end
end

ActiveSupport.on_load(:active_record) do
  include ValidationReflection
  ::ValidationReflection.install(self)
end
