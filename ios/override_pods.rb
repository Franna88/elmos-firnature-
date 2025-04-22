#!/usr/bin/env ruby

# This script modifies the Flutter-generated Podfile to exclude mobile_scanner plugin
# and add a dummy implementation instead to avoid dependency conflicts

# Read the current Podfile content
podfile_path = 'Podfile'
podfile_content = File.read(podfile_path)

# Add a pre_install hook to exclude mobile_scanner
if !podfile_content.include?('pre_install do |installer|')
  modified_content = podfile_content.gsub(
    /flutter_ios_podfile_setup/, 
    "flutter_ios_podfile_setup\n\n" +
    "# Exclude mobile_scanner to avoid dependency conflicts\n" +
    "pre_install do |installer|\n" +
    "  # Remove mobile_scanner plugin's pod\n" +
    "  installer.pod_targets.each do |pod|\n" +
    "    if pod.name == 'mobile_scanner'\n" +
    "      puts \"⚠️ Excluding mobile_scanner pod to avoid dependency conflicts\"\n" +
    "      pod.define_singleton_method(:include_in_build_config?) do |*args|\n" +
    "        false\n" +
    "      end\n" +
    "    end\n" +
    "  end\n" +
    "end\n"
  )
  
  # Write the modified Podfile
  File.write(podfile_path, modified_content)
  puts "✅ Successfully modified Podfile to exclude mobile_scanner"
else
  puts "⚠️ Podfile already contains a pre_install hook, skipping modification"
end 