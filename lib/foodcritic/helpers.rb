require 'nokogiri'
require 'xmlsimple'

module FoodCritic

  # Helper methods that form part of the Rules DSL.
  module Helpers

    # Create a match from the specified node.
    #
    # @param [Nokogiri::XML::Node] node The node to create a match for
    # @return [Hash] Hash with the matched node name and position with the recipe
    def match(node)
      pos = node.xpath('descendant::pos').first
      {:matched => node.respond_to?(:name) ? node.name : '', :line => pos['line'], :column => pos['column']}
    end

    # Does the specified recipe check for Chef Solo?
    #
    # @param [Nokogiri::XML::Node] ast The AST of the cookbook recipe to check.
    # @return [Boolean] True if there is a test for Chef::Config[:solo] in the recipe
    def checks_for_chef_solo?(ast)
      ! ast.xpath(%q{//if/aref[count(descendant::const[@value = 'Chef' or @value = 'Config']) = 2 and
          count(descendant::ident[@value='solo']) > 0]}).empty?
    end

    # Searches performed by the specified recipe.
    #
    # @param [Nokogiri::XML::Node] ast The AST of the cookbook recipe to check.
    # @return [Boolean] True if the recipe performs a search
    def searches(ast)
      ast.xpath("//fcall/ident[@value = 'search']")
    end

    # Find Chef resources of the specified type.
    # TODO: Include blockless resources
    #
    # @param [Nokogiri::XML::Node] ast The AST of the cookbook recipe to check
    # @param [String] type The type of resource to look for (or nil for all resources)
    def find_resources(ast, type = nil)
      ast.xpath(%Q{//method_add_block[command/ident#{type.nil? ? '' : "[@value='#{type}']"}]})
    end

    # Return the type, e.g. 'package' for a given resource
    #
    # @param [Nokogiri::XML::Node] resource The resource AST
    # @return [String] The type of resource
    def resource_type(resource)
      resource.xpath('string(command/ident/@value)')
    end

    # Retrieve the name attribute associated with the specified resource.
    #
    # @param [Nokogiri::XML::Node] resource The resource AST to lookup the name attribute under
    def resource_name(resource)
      resource.xpath('string(command//tstring_content/@value)')
    end

    # Retrieve a single-valued attribute from the specified resource.
    #
    # @param [String] name The attribute name
    # @param [Nokogiri::XML::Node] resource The resource AST to lookup the attribute under
    # @return [String] The attribute value for the specified attribute
    def resource_attribute(name, resource)
      resource_attributes(resource)[name]
    end

    # Retrieve all attributes from the specified resource.
    #
    # @param [Nokogiri::XML::Node] resource The resource AST
    # @return [Hash] The resource attributes
    def resource_attributes(resource)
      atts = {:name => resource_name(resource)}
      resource.xpath('do_block/descendant::command').each do |att|
        if att.xpath('descendant::symbol').empty?
          att_value = att.xpath('string(descendant::tstring_content/@value)')
        else
          att_value = att.xpath('string(descendant::symbol/ident/@value)').to_sym
        end
        atts[att.xpath('string(ident/@value)')] = att_value
      end
      atts
    end

    # Retrieve all resources of a given type
    #
    # @param [Nokogiri::XML::Node] ast The recipe AST
    # @return [Hash] The matching resources
    def resources_by_type(ast)
      result = Hash.new{|hash, key| hash[key] = Array.new}
      find_resources(ast).each{|resource| result[resource_type(resource)] << resource}
      result
    end

    # Retrieve the attributes as a hash for all resources of a given type.
    #
    # @param [Nokogiri::XML::Node] ast The recipe AST
    # @return [Hash] An array of resource attributes keyed by type.
    def resource_attributes_by_type(ast)
      result = {}
      resources_by_type(ast).each do |type,resources|
        result[type] = resources.map{|resource| resource_attributes(resource)}
      end
      result
    end

    # Retrieve the recipes that are included within the given recipe AST.
    #
    # @param [Nokogiri::XML::Node] ast The recipe AST
    # @return [Hash] include_recipe nodes keyed by included recipe name
    def included_recipes(ast)
      # we only support literal strings, ignoring sub-expressions
      included = ast.xpath(%q{//command[ident/@value = 'include_recipe' and count(descendant::string_embexpr) = 0]/
        descendant::tstring_content})
      Hash[included.map{|recipe|recipe['value']}.zip(included)]
    end

    # The name of the cookbook containing the specified file.
    #
    # @param [String] file The file in the cookbook
    # @return [String] The name of the containing cookbook
    def cookbook_name(file)
      File.basename(File.absolute_path(File.join(File.dirname(file), '..')))
    end

    # The dependencies declared in cookbook metadata.
    #
    # @param [Nokogiri::XML::Node] ast The metadata rb AST
    # @return [Array] List of cookbooks depended on
    def declared_dependencies(ast)
      deps = ast.xpath("//command[ident/@value='depends']/descendant::args_add/descendant::tstring_content")
      # handle quoted word arrays
      var_ref = ast.xpath("//command[ident/@value='depends']/descendant::var_ref/ident")
      deps += ast.xpath(%Q{//block_var/params/ident#{var_ref.first['value']}/ancestor::method_add_block/
          call/descendant::tstring_content}) unless var_ref.empty?
      deps.map{|dep| dep['value']}
    end

    # If the provided node is the line / column information.
    #
    # @param [Nokogiri::XML::Node] node A node within the AST
    # @return [Boolean] True if this node holds the position data
    def position_node?(node)
      node.respond_to?(:length) and node.length == 2 and node.respond_to?(:all?) and node.all?{|child| child.respond_to?(:to_i)}
    end

    # Recurse the nested arrays provided by Ripper to create an intermediate Hash for ease of searching.
    #
    # @param [Nokogiri::XML::Node] node The AST
    # @return [Hash] The friendlier Hash.
    def ast_to_hash(node)
      result = {}
      if node.respond_to?(:each)
        node.drop(1).each do |child|
          if position_node?(child)
            result[:pos] = {:line => child.first, :column => child[1]}
          else
            if child.respond_to?(:first)
              result[child.first.to_s.gsub(/[^a-z_]/, '')] = ast_to_hash(child)
            else
              result[:value] = child  unless child.nil?
            end
          end
        end
      end
      result
    end

    # Read the AST for the given Ruby file
    #
    # @param [String] file The file to read
    # @return [Nokogiri::XML::Node] The recipe AST
    def read_file(file)
      Nokogiri::XML(XmlSimple.xml_out(ast_to_hash(Ripper::SexpBuilder.new(IO.read(file)).parse)))
    end

  end

end
