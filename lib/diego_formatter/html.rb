require 'rubygems'
require 'fileutils'
require 'erb'
require 'cucumber/formatter/ordered_xml_markup'
require 'cucumber/formatter/duration'
require 'cucumber/formatter/io'
require 'cucumber/formatter/html'
require 'cucumber/formatter/summary'
require 'active_support/all'

require_relative 'mixins/asset_methods'

module Cucumber
  module Formatter
    module Relaxdiego
      class Html

        include ERB::Util # for the #h method
        include Duration
        include Io
        include Summary
        include ActiveSupport::Inflector

        include AssetMethods

        def initialize(step_mother, path_or_io, options)
          @report_dir = ensure_dir(path_or_io, "html")
          @total_features = 0
          @processed_features = 0
          @results = {}
          @current_category
          @current_feature

          ensure_assets(@report_dir)

          FileUtils.rm_rf(screenshots_dir) if Dir.exists?(screenshots_dir)
          Dir.mkdir(screenshots_dir)
        end

        def before_features(features)
          features.each { |f| @total_features += 1 }
          show_progress(0, @total_features, "features")
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
          name, desc = split_name_and_desc(name_and_desc)
          @current_feature_element[:type] = "Background"
          @current_feature_element[:name] = name
          @current_feature_element[:description] = desc
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
          @current_step_is_background = is_background
          step_name = step_match.format_args(lambda{|param| %{#{param}}})
          step = { :keyword => keyword.gsub('*','').strip,
                   :status  => status,
                   :name    => h(step_name).gsub(/&lt;([\w ]+)&gt;/, '<code>\1</code>') }
          @current_step = step
          return if skip_current_step?

          @current_feature_element[:steps] << step
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
          @processed_features += 1
          show_progress(@processed_features, @total_features, "features")
        end

        def after_features(features)
          print "\n"
          write_html
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
          return if skip_current_step?
          @current_table = []
          @current_step[:table] = @current_table unless multiline_arg.class == Cucumber::Ast::DocString
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
          if table_row.exception
            @current_row.each do |cell|
              if [:failed, :undefined].include?(cell[:status])
                cell[:exception] = build_exception_detail(table_row.exception)
                break
              end
            end
          end
        end

        def after_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background)
          # Do nothing
        end

        #==================================================
        # Methods for inserting images to the report
        #==================================================

        def screenshots_dir
          File.join(@report_dir, "screenshots")
        end

        def embed(src, mime_type, label)
          case(mime_type)
          when /^image\/(png|gif|jpg|jpeg)/
            filename = src.split('/')[-1]
            filepath = File.join(screenshots_dir, filename)
            FileUtils.cp(src, filepath)

            if is_scenario_outline?(@current_feature_element)
              @current_row.each do |cell|
                if cell[:status] == :failed
                  cell[:screenshot] = "screenshots/#{filename}"
                  break
                end
              end
            elsif !is_scenario_outline?(@current_feature_element)
              @current_step[:screenshot] = "screenshots/#{filename}"
            end
          end
        end

        #==================================================
        # Methods for embedding exceptions in the report
        #==================================================

        def exception(exception, status)
          @current_step[:exception] = build_exception_detail(exception)
        end

        def build_exception_detail(exception)
          exception_hash = {}
          backtrace = Array.new

          message = exception.message
          unless exception.instance_of?(RuntimeError)
            message = "#{message} (#{exception.class})"
          end
          exception_hash[:message] = message

          backtrace = exception.backtrace
          backtrace.delete_if { |x| x =~ /\/gems\/(cucumber|rspec)/ }
          exception_hash[:backtrace] = backtrace

          snippet_extractor ||= Cucumber::Formatter::Html::SnippetExtractor.new
          extra = snippet_extractor.snippet(backtrace)
          exception_hash[:extra_failure_content] = extra

          exception_hash
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
          if @in_feature_element
            @current_feature_element[:tags] ||= []
            @current_feature_element[:tags] << tag_name
          else
            @current_feature[:tags] ||= []
            @current_feature[:tags] << tag_name
          end
        end

        def after_tags(tags)
        end

        protected

        def write_html
          template = File.open(File.expand_path('../templates/html.erb', __FILE__), 'r')
          erb = ERB.new(template.read)
          File.open(File.join(@report_dir, "index.html"), 'w') { |file| file.write(erb.result(binding)) }
          puts "HTML report saved as #{@report_dir}/index.html"
        end

        # def asset_tags
        #   tags = ""
        #   destination_dir = File.join(@report_dir, "assets")
        #
        #   dir = Dir.open(File.dirname(__FILE__))
        #
        #   Dir.mkdir(destination_dir) unless Dir.exists?(destination_dir)
        #
        #   dir.entries.select { |e| e.match /.+\.(css|js|png)/ }.each do |f|
        #     type = f.split('.')[-1]
        #     type = "img" if type == 'png'
        #
        #     Dir.mkdir(File.join(destination_dir, type)) unless Dir.exists?(File.join(destination_dir, type))
        #
        #     FileUtils.cp(File.join(File.dirname(__FILE__), f), File.join(@report_dir, "assets", type, f))
        #
        #     if type == 'css'
        #       tags << "<link type='text/css' rel='stylesheet' href='#{ File.join("assets", type, f) }'>\n"
        #     elsif type == 'js'
        #       tags << "<script src='#{ File.join("assets", type, f) }' type='text/javascript'></script>\n"
        #     end
        #   end
        #
        #   tags
        # end

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

        def show_progress(current, total, what)
          # print "Processed #{current} of #{total} #{what}\r"
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

        def get_status(feature)
          @statuses ||= {}
          return @statuses[feature[:name]] unless @statuses[feature[:name]].nil?
          return :undefined if feature[:elements].nil?

          status = nil

          feature[:elements].each do |element|
            if is_scenario_outline?(element)
              # Go through the examples instead of the steps
              element[:examples].each do |examples|
                (1...examples[:rows].length).each do |index|
                  examples[:rows][index].each do |cell|
                    status = cell[:status] unless cell[:status] == :passed
                    break if status
                  end
                  break if status
                end
              end
            else
              # Go through the steps
              element[:steps].each do |step|
                status = step[:status] unless step[:status] == :passed
                break if status
              end
            end

            break if status
          end

          status ||= :passed

          @statuses[feature[:name]] = status
          status
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
