require 'rubygems'
require 'fileutils'
require 'erb'
require 'cucumber/formatter/ordered_xml_markup'
require 'cucumber/formatter/duration'
require 'cucumber/formatter/io'
require 'cucumber/formatter/html'
require 'cucumber/formatter/summary'
require 'active_support/all'

module Cucumber
  module Formatter
    module Relaxdiego
      class PermissionsMatrix

        include Duration
        include Io
        include Summary
        include ActiveSupport::Inflector

        def initialize(step_mother, path_or_io, options)
          @report_dir = ensure_dir(path_or_io, "permissions")
          @results = {}
          @current_category
          @current_feature
        end

        def before_features(features)
        end

        # Assumes that the .feature file is at least two levels down from
        # the feature directory. e.g. features/somedir/category1/feature_name.feature
        # In the above example, "features" and "somedir" are ignored
        def before_feature(feature)
          @current_category = get_current_category(:path => feature.file, :root_category => @results)
          @current_feature = {}
        end

        def feature_name(keyword, name_and_desc)
          name, desc = split_name_and_desc(name_and_desc)
          @current_feature[:name] = name
          @current_feature[:description] = desc
          @current_category << @current_feature
        end

        def before_background(background)
          @current_feature[:elements] = [] if @current_feature[:elements].nil?
          @current_feature_element = {}
          @current_feature[:elements] << @current_feature_element
        end

        def background_name(keyword, name_and_desc, file_colon_line, source_indent)
          # Do nothing
        end

        def after_background(background)
          # Do nothing
        end

        # Called for Scenario and Scenario Outline.
        # May be called for other elements should
        # Cucumber add a new type in future versions.
        def before_feature_element(feature_element)
          @in_feature_element = true
          @current_feature[:elements] = [] if @current_feature[:elements].nil?
          @current_feature_element = {}
          @current_feature[:elements] << @current_feature_element
        end

        def scenario_name(keyword, name_and_desc, file_colon_line, source_indent)
          name, desc = split_name_and_desc(name_and_desc)
          @current_feature_element[:type] = keyword
          @current_feature_element[:name] = name
          @current_feature_element[:description] = desc
        end

        # Can be called for a Scenario, Scenario Outline, or Background
        def before_steps(steps)
          @current_feature_element[:steps] = []
        end

        # Can be a Scenario, Scenario Outline, or Background step
        def before_step(step)
          # Do nothing
        end

        # Can be a Scenario, Scenario Outline, or Background step
        def before_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background)
          # Do nothing
        end

        # Can be a Scenario, Scenario Outline, or Background step
        def step_name(keyword, step_match, status, source_indent, is_background)
          # Do nothing
        end

        def after_step(step)
          # Do nothing
        end

        def after_steps(steps)
          # Do nothing
        end

        def after_feature_element(feature_element)
          @in_feature_element = false
        end

        def after_feature(feature)
          # Do nothing
        end

        def after_features(features)
          write_matrix
        end

        #=================================================
        # Other methods called within a feature element
        # These tend to be shared between the three types
        # (Background, Scenario, and Scenario Outline)
        #=================================================

        # Denotes the beginning of a Scenario or Background table
        # Does NOT denote a Scenario Outline table
        # See before_outline_table instead.
        def before_multiline_arg(multiline_arg)
          # Do nothing
        end

        def after_multiline_arg(multiline_arg)
          # Do nothing
        end

        def before_examples(examples)
          @examples = true
        end

        def examples_name(keyword, name_and_desc)
          name, desc = split_name_and_desc(name_and_desc)
          @examples = {
            :type => keyword,
            :name => name,
            :description => desc,
            :rows => []
          }
          @current_feature_element[:examples] ||= []
          @current_feature_element[:examples] << @examples
        end

        def after_examples(examples)
          @examples = false
        end

        # Denotes the beginning of a Scenario Outline table
        # Does NOT denote a Scenario or Background table
        # See before_multiline_arg instead
        def before_outline_table(outline_table)
          @current_table = @examples[:rows]
        end

        def after_outline_table(outline_table)
        end

        #==================================================
        # Methods involving tables (Examples or Multi-line
        # arguments). May also be called within a step that
        # is part of a background (which gets called for
        # every scenario and scenario outline in a feature)
        # In that case, we want to skip it.
        #==================================================

        def before_table_row(table_row)
          return if skip_current_step?
          @current_row = []
          @current_table << @current_row
        end

        def table_cell_value(value, status)
          return if skip_current_step?
          @previous_cell = @current_cell
          @current_cell = { :value => value, :status => status }
          @current_row << @current_cell
        end

        def after_table_row(table_row)
          # Do nothing
        end

        def after_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background)
          # Do nothing
        end

        #==================================================
        # Unused methods
        #==================================================

        def doc_string(doc_string)
          @current_step[:doc_string] = doc_string.to_s
        end

        def before_comment(comment)
        end

        def comment_line(comment_line)
        end

        def after_comment(comment)
        end

        def before_tags(tags)
        end

        def tag_name(tag_name)
          # Do nothing
        end

        def after_tags(tags)
        end

        protected

        def write_matrix
          # template = File.open(File.expand_path('../html.erb', __FILE__), 'r')
          # erb = ERB.new(template.read)
          # File.open(File.join(@report_dir, "index.html"), 'w') { |file| file.write(erb.result(binding)) }
          # puts "Permission matrix saved as #{@report_dir}/matrix.csv"
          roles = []
          @results.each do |category_name, category|
            category.each do |feature|
              feature[:elements].find{ |e| e[:type]=="Scenario Outline"}[:examples].each do |example|
                role = example[:rows][1][0][:value]
                roles << role unless roles.include?(role)
              end
            end
          end

          roles.sort!{|a,b| a<=>b}

          separator = ","
          first_column_pad = 50
          csv = ""
          csv << "".ljust(first_column_pad) + ",#{ roles.join(',') }\n"

          @results.each do |category_name, category|
            # puts category_name
            csv << category_name.ljust(first_column_pad).upcase
            roles.length.times { csv << separator }
            csv << "\n"
            category.each do |feature|
              # puts "  #{feature[:name]}"
              csv << feature[:name].ljust(first_column_pad)
              feature_permissions = []
              feature[:elements].find{ |e| e[:type]=="Scenario Outline"}[:examples].each do |example|
                example[:rows].delete_at(0)
                example[:rows].each do |row|
                  feature_permissions << { row[0][:value] => (row[1][:value] =~ /^Cannot/ ? '' : 'Y' ) }
                end
              end
              # puts feature_permissions.inspect
              roles.each do |role|
                # puts "#{ role }: #{ feature_permissions.find{ |p| p.keys[0] == role }[role] }"
                csv << "#{ separator }#{ feature_permissions.find{ |p| p.keys[0] == role }[role] }"
              end
              csv << "\n"
            end
            csv << "".ljust(first_column_pad)
            roles.length.times { csv << separator }
            csv << "\n"
          end

          File.open(File.join(@report_dir, "matrix.csv"), 'w') { |file| file.write(csv) }
          puts "Permission matrix saved as #{@report_dir}/matrix.csv"
        end

        def get_current_category(args)
          path = args[:path].split('/')

          # Remove first two directories and the feature filename
          2.times { path.delete_at(0) }
          path.delete_at(path.length - 1)

          current_category = args[:root_category]
          path.each_with_index do |sub_cat, index|
            # If we've reached the end of the path, make the sub-category an array (of features)
            current_category[sub_cat] = (index < path.length-1 ? {} : []) if current_category[sub_cat].nil?
            current_category = current_category[sub_cat]
          end

          current_category
        end

        def skip_current_step?
          @current_step_is_background && @current_feature_element[:type].downcase != "background"
        end

        def split_name_and_desc(name_and_desc)
          lines = name_and_desc.split("\n")
          name = lines.delete_at(0) || ""
          description = ""
          lines.each do |line|
            description << (line.strip == '' ? "<br><br>" : line)
          end
          return name.strip, description.strip
        end

        #==================================================
        # Template helper methods
        #==================================================

        def build_bookmark(category, feature)
          "#{category}-#{feature[:name].parameterize}"
        end

        def build_id(feature, element, step)
          "#{ feature }#{ element }#{ step }".parameterize
        end

        def feature_label_type(feature)
          label_type( get_status(feature) )
        end

        def feature_status_text(feature)
          status_text( get_status(feature) )
        end

        def is_scenario_outline?(element)
          !element[:examples].nil?
        end

        def has_jira_tags?(feature_or_element)
          return !jira_tags(feature_or_element).nil? &&
                 !jira_tags(feature_or_element).empty?
        end

        def jira_tags(feature_or_element)
          return [] unless feature_or_element[:tags]

          feature_or_element[:tags].select { |tag| tag =~ /^@jira-/ }
        end

        def all_tags(feature_or_element)
          feature_or_element[:tags] || []
        end

        def non_jira_tags(feature_or_element)
          tags = feature_or_element[:tags] || []
          tags.select { |tag| tag.match(/^@jira-/).nil? }
        end

        def jira_issue_link_or_text(tag)
          tag.gsub! /^@jira-/, ''
          if tag =~ /^\S-\d+/
            "<a href='https://issues.morphlabs.com/browse/#{tag}' target='__jira__'>#{tag}</a>"
          else
            tag
          end
        end

        def label_type(status)
          css = "label-"

          case status
          when :undefined
            css << 'warning'
          when :passed
            css << 'success'
          when :failed
            css << 'important'
          when :pending
            css << 'warning'
          else
            css << ''
          end

          css
        end

        def status_text(status)
          case status
          when :undefined
            'U'
          when :passed
            'OK'
          when :failed
            'F'
          when :skipped
            'S'
          when :pending
            'P'
          else
            ''
          end
        end

        def compute_statistics
          return if @stats

          @stats = {}
          @stats[:total_completed_features] = 0
          @stats[:total_features] = 0
          @stats[:total_undefined_features] = 0

          @results.each do |category_name, features|
            features.each do |feature|
              @stats[:total_completed_features] += 1 if get_status(feature) == :passed
              @stats[:total_features] += 1
              @stats[:total_undefined_features] += 1 if get_status(feature) != :passed
            end
          end
        end

        def total_completed_features
          compute_statistics
          @stats[:total_completed_features]
        end

        def total_features
          compute_statistics
          @stats[:total_features]
        end

        def total_undefined_features
          compute_statistics
          @stats[:total_undefined_features]
        end

      end #class Html
    end # module Relaxdiego
  end # module Formatter
end # module Cucumber
