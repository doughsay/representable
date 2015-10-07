module Representable
  # Allows to implement a pipeline of filters where a value gets passed in and the result gets
  # passed to the next callable object.
  class Pipeline < Array
    include Uber::Callable
    # include Representable::Cloneable

    Stop = Class.new

    # options is mutuable.
    def call(input, options)
      inject(input) do |memo, block|
        evaluate(block, memo, options).tap do |res|
          return Stop if res == Stop
        end
      end
    end

  private
    def evaluate(block, input, options)
      block.call(input, options)
    end


    module Debug
      def call(input, options)
        puts "Pipeline#call: #{inspect}"
        puts "               input: #{input.inspect}"
        super
      end

      def evaluate(block, memo, options)
        puts "  Pipeline   :   -> #{_inspect_function(block)} "
        super.tap do |res|
          puts "  Pipeline   :     result: #{res.inspect}"
        end
      end

      def inspect
        collect do |func|
          _inspect_function(func)
        end.join(", ")
      end

      # prints SkipParse instead of <Proc>. i know, i can make this better, but not now.
      def _inspect_function(func)
        return func unless func.is_a?(Proc)
        File.readlines(func.source_location[0])[func.source_location[1]-1].match(/^\s+(\w+)/)[1]
      end
    end
  end

  # Collect applies a pipeline to each element of options[:fragment].
  class Collect
    def self.[](*functions)
      new(Pipeline[*functions])
    end

    def initialize(functions)
      @item_pipeline = functions.extend(Pipeline::Debug)
    end

    # when stop, the element is skipped. (should that be Skip then?)
    def call(input, options)
      arr = []
      input.each_with_index do |item_fragment, i|
        result = @item_pipeline.(item_fragment, options.merge(index: i)) # DISCUSS: NO :fragment set.

        next if result == Pipeline::Stop
        arr << result
      end
      arr
    end


    class Hash < self
      def call(input, options)
        {}.tap do |hsh|
          input.each { |key, item_fragment|
            hsh[key] = @item_pipeline.(item_fragment, options) }# DISCUSS: NO :fragment set.

        end
      end
    end
  end
end
