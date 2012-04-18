module Cucumber
module Formatter
module Relaxdiego
module AssetMethods

  ASSET_DIRS = ['img', 'javascripts', 'stylesheets']

  def ensure_assets
    asset_paths = {}
    ASSET_DIRS.each do |subdir_name|
      asset_paths[subdir_name.to_sym] ||= []
      source_dir = Dir.open(File.join(File.dirname(__FILE__), subdir_name))

      unless Dir.exists?(File.join(@report_dir, subdir_name))
        Dir.mkdir(File.join(@report_dir, subdir_name))
      end

      source_dir.entries.each do |file_name|
        next if file_name =~ /^\.\.?$/

        file_name_with_stamp = build_file_name_with_stamp(source_dir.path, file_name) unless subdir_name == 'img'
        source_file = File.join(source_dir.path, file_name)
        destination_file = File.join(@report_dir, subdir_name, file_name_with_stamp || file_name)
        unless File.exists?(destination_file)
          FileUtils.cp(source_file, destination_file)
        end
        asset_paths[subdir_name.to_sym] << File.join(subdir_name, file_name_with_stamp || file_name)
        file_name_with_stamp = nil
      end
    end
    asset_paths
  end

end
end
end
end