require 'imgkit'
IMGKit.configure do |config|
	config.wkhtmltoimage = './bin/64/wkhtmltoimage'
	config.default_options = {
		:quality => 60
	}	
end
