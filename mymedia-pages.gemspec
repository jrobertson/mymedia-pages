Gem::Specification.new do |s|
  s.name = 'mymedia-pages'
  s.version = '0.5.4'
  s.summary = 'A MyMedia gem to publish a basic web page'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mymedia-pages.rb']
  s.add_runtime_dependency('mymedia', '~> 0.5', '>=0.5.2')
  s.add_runtime_dependency('martile', '~> 1.5', '>=1.5.0')
  s.add_runtime_dependency('kramdown', '~> 2.3', '>=2.3.2')
  s.signing_key = '../privatekeys/mymedia-pages.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/mymedia-pages'
end
