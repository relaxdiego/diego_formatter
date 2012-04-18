module Cucumber
module Formatter
module Relaxdiego
module AssetMethods

  ASSET_SUBDIR_NAMES = ['img', 'javascripts', 'stylesheets']

  def ensure_assets(report_dir)
    ASSET_SUBDIR_NAMES.each do |subdir_name|
      source_dir_path = File.join(File.expand_path('../..', __FILE__), subdir_name)
      target_dir_path = File.join(report_dir, subdir_name)

      Dir.mkdir(target_dir_path) unless Dir.exists?(target_dir_path)

      source_dir = Dir.open(source_dir_path)
      source_dir.entries.each do |source_file_name|
        next if source_file_name =~ /^\.\.?$/
        ensure_asset(source_file_name, source_dir_path, target_dir_path)
      end
    end
  end

  def ensure_asset(source_file_name, source_dir_path, target_dir_path)
    if source_dir_path =~ /img$/
      target_file_name = source_file_name
    else
      target_file_name = build_file_name_with_stamp(source_dir_path, source_file_name)
    end

    source_file_path = File.join(source_dir_path, source_file_name)
    target_file_path = File.join(target_dir_path, target_file_name)
puts target_file_path
    # FileUtils.cp(source_file_path, target_file_path) unless File.exists?(target_file_path)
  end

  def build_file_name_with_stamp(path, file_name)
    with_stamp      = file_name
    name_components = file_name.split('.')

    with_stamp = name_components[0]
    with_stamp << "-#{File.mtime(File.join(path, file_name)).strftime('%Y%m%dT%H%M%S')}."
    with_stamp << name_components[1, name_components.length - 1].join('.')
  end

end
end
end
end