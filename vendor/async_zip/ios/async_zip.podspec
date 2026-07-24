Pod::Spec.new do |s|
  s.name             = 'async_zip'
  s.version          = '0.0.1'
  s.summary          = 'Asynchronous reading and writing of Zip files.'
  s.description      = '–'
  s.homepage         = 'https://github.com/perron2/async_zip'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Perron2 GmbH' => 'info@perron2.ch' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
