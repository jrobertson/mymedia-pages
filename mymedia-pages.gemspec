Gem::Specification.new do |s|
  s.name = 'mymedia-pages'
  s.version = '0.1.7'
  s.summary = 'A MyMedia gem to publish a basic web page'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_runtime_dependency('mymedia', '~> 0.1', '>=0.1.1')
  s.add_runtime_dependency('martile', '~> 0.4', '>=0.4.1')
  s.signing_key = '../privatekeys/mymedia-pages.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/mymedia-pages'
end
