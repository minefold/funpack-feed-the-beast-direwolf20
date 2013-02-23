require 'brock'
require 'erb'

class Settings
  attr_reader :schema, :values

  def initialize(definitions, values={})
    @schema = Brock::Schema.new(definitions)
    @values = values
  end

  def field(name)
    field = schema.fields.find{|f| f.name.to_sym == name.to_sym }
    value = (values[name] || values[name.to_sym])

    raise "Unknown field: #{name}" if field.nil? and value.nil?
    
    if field
      if value.nil?
        field.default
      else
        field.parse_param(value)
      end
    else
      value
    end
  end
  
  alias_method :f, :field

  def erb(template)
    ERB.new(template).result(binding)
  end
end