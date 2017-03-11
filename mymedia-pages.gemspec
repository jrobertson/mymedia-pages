Gem::Specification.new do |s|
  s.name = 'mymedia-pages'
  s.version = '0.2.0'
  s.summary = 'A MyMedia gem to publish a basic web page'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mymedia-pages.rb']
  s.add_runtime_dependency('mymedia', '~> 0.1', '>=0.1.1')
  s.add_runtime_dependency('martile', '~> 0.4', '>=0.4.1')
  s.add_runtime_dependency('kramdown', '~> 1.13', '>=1.13.2')
  s.signing_key = '../privatekeys/mymedia-pages.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/mymedia-pages'
end
