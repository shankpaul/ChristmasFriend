require 'imgkit'
IMGKit.configure do |config|
	config.wkhtmltoimage = './bin/wkhtmltoimage'
	config.default_options = {
		:quality => 60
	}	
end