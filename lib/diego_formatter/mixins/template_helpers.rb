module Cucumber
module Formatter
module Relaxdiego
module TemplateHelpers

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

end
end
end
end