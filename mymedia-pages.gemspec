Gem::Specification.new do |s|
  s.name = 'mymedia-pages'
  s.version = '0.3.1'
  s.summary = 'A MyMedia gem to publish a basic web page'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mymedia-pages.rb']
  s.add_runtime_dependency('mymedia', '~> 0.2', '>=0.2.14')
  s.add_runtime_dependency('martile', '~> 1.1', '>=1.1.0')  
  s.add_runtime_dependency('kramdown', '~> 2.3', '>=2.3.1')
  s.signing_key = '../privatekeys/mymedia-pages.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/mymedia-pages'
end
