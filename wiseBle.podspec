Pod::Spec.new do |s|
s.name = 'wiseBle'
s.version = '1.0.0'
s.license = 'GPL-2.0'
s.summary = '蓝牙操作的类库'
s.homepage = 'https://github.com/diaoerlangdang/WiseBle'
s.authors = { 'wise' => '99487616@qq.com' }
s.source = { :git => 'https://github.com/diaoerlangdang/WiseBle.git', :tag => s.version.to_s }
s.requires_arc = true
s.ios.deployment_target = '8.0'
s.source_files = 'wiseBle/**/*'
end