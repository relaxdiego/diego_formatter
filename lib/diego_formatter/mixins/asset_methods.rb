module Cucumber
module Formatter
module Relaxdiego
module AssetMethods

  ASSET_SUBDIR_NAMES = ['img', 'javascripts', 'stylesheets']

  def build_file_name_with_stamp(path, file_name)
    with_stamp      = file_name
    name_components = file_name.split('.')

    with_stamp = name_components[0]
    with_stamp << "-#{File.mtime(File.join(path, file_name)).strftime('%Y%m%dT%H%M%S')}."
    with_stamp << name_components[1, name_components.length - 1].join('.')
  end

  def copy_asset(source_file_name, source_dir_path, target_dir_path)
    asset_is_an_image = source_dir_path =~ /img$/

    if asset_is_an_image
      # Don't add a timestamp to the filename since some CSS files
      # (e.g. bootstrap) might be referencing the file
      target_file_name = source_file_name
    else
      target_file_name = build_file_name_with_stamp(source_dir_path, source_file_name)
    end

    source_file_path = File.join(source_dir_path, source_file_name)
    target_file_path = File.join(target_dir_path, target_file_name)

    # Except for images, if the timestamped file already exists, then don't copy it
    if asset_is_an_image || !File.exists?(target_file_path)
      delete_all_asset_versions(target_dir_path, source_file_name)
      FileUtils.cp(source_file_path, target_file_path)
    end
  end

  def delete_all_asset_versions(target_dir_path, file_name)
    name_components = file_name.split('.')
    all_versions = Dir["#{target_dir_path}/#{ name_components[0] }*.#{ name_components[1, name_components.length - 1].join('.') }"]

    all_versions.each do |file_path|
      File.delete(file_path)
    end
  end

  def ensure_assets(report_dir)
    ASSET_SUBDIR_NAMES.each do |subdir_name|
      source_dir_path = File.join(File.expand_path('../..', __FILE__), subdir_name)
      target_dir_path = File.join(report_dir, subdir_name)

      Dir.mkdir(target_dir_path) unless Dir.exists?(target_dir_path)

      source_dir = Dir.open(source_dir_path)
      source_dir.entries.each do |source_file_name|
        next if source_file_name =~ /^\.\.?$/
        copy_asset(source_file_name, source_dir_path, target_dir_path)
      end
    end
  end

end
end
end
end