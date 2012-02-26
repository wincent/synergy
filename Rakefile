require 'pathname'

def release_version
  return @release_version if @release_version
  version_file = Pathname.new('WOSynergy_Version.h').read
  version_line = version_file.lines.find do |line|
    line =~ /\A#define\s+WO_INFO_PLIST_VERSION\s+(.+)\s*\z/
  end or raise "could not find version number"
  @release_version = $~[1]
end

desc 'create a Git tag for the current build'
task :tag do
  if release_version=~ /\+\z/
    raise "refusing to tag intermediate (not official release) version " +
          "(version number '#{release_version}' ends in '+')"
  else
    sh "./tag-release.sh #{release_version}"
  end
end

desc 'upload the current build to Amazon S3'
task :upload do
  sh 'aws put ' +
     "s3.wincent.com/synergy/releases/synergy-#{release_version}.zip " +
     "../../build/Release/synergy-#{release_version}.zip"
  sh 'aws put ' +
     "s3.wincent.com/synergy/releases/synergy-#{release_version}.zip?acl " +
     '--public'
end
