Gem::Specification.new do |s|
  s.name = 'mymedia-pages'
  s.version = '0.2.1'
  s.summary = 'A MyMedia gem to publish a basic web page'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mymedia-pages.rb']
  s.add_runtime_dependency('mymedia', '~> 0.2', '>=0.2.14')
  s.add_runtime_dependency('martile', '~> 0.9', '>=0.9.0')
  s.add_runtime_dependency('kramdown', '~> 1.16', '>=1.16.2')
  s.signing_key = '../privatekeys/mymedia-pages.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/mymedia-pages'
end
