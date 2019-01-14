#!/usr/bin/ruby
# Written by Sourav Goswami
# Special thanks to Srilekha Das for suggesting the look and feel ;)
# Thanks to the Ruby2D community ;)
# The GNU General Public License v3.0

require 'net/http'
require 'open-uri'
require 'json'
require 'ruby2d'
require 'time'
require 'timeout'
require 'securerandom'
STDOUT.sync = true

module Ruby2D
	def total_x() @x + @width end
	def total_y() @y + @height end
	def change_colour(colour="##{SecureRandom.hex(3)}")
		_opacity, self.color = self.opacity, colour
		self.opacity = _opacity
	end
end

# Errors first
Err_No_Config_File = 1
Err_No_Location = 2
Err_Invalid_Key = 3
Err_Others = 4

# Specify where the configuration file is
ConfPath = "#{File.dirname(__FILE__)}/config.conf"

config_file = ''
loop do
	if File.readable?(ConfPath)
		config_file = File.readlines('config.conf')
		break
	else
		STDERR.puts 'The config file is not readable. Download from the internet? (Y/n)'
		exit! Err_No_Config_File if STDIN.gets.strip.downcase == 'n'
		begin
			File.write(ConfPath, Net::HTTP.get(URI('https://raw.githubusercontent.com/Souravgoswami/Ruby2D-Apixu-Weather/master/config.conf')))
		rescue SocketError
			warn 'No Internet Connection?'
		rescue Exception
		end
	end
end

Screenshot_Dir = 'Screenshots/'
Dir.mkdir(Screenshot_Dir) unless File.readable?(Screenshot_Dir)

UI = "#{File.dirname(__FILE__)}/UI/"
Dir.mkdir(UI) unless File.readable?(UI)

read_config = ->(key) { config_file.select { |opt| opt.strip.downcase.start_with?(key.strip.downcase) }[-1].to_s.split('=')[1].to_s.strip.delete('"\'') }

Resizable = read_config.call('Resizable') == 'false' ? false : true
Unit = read_config.call('Unit').downcase == 'f' ? 'f' : 'c'
Measure_Unit = read_config.call('Measure_Unit').downcase == 'mph' ? 'mph' : 'kph'
No_Particles = read_config.call('No_Particles').to_i
Particle_Blink = read_config.call('Particle_Blink') != 'false'
Particle_Fadeout = read_config.call('Particle_Fadeout').to_f
Verbose = read_config.call('Verbose') != 'false'
Download_Background = read_config.call('Download_Background') != 'false'
Custom_BG_Zoom = read_config.call('Custom_BG_Zoom') == 'true'

temp = read_config.call('Width').to_i
$width = temp < 550 ? 550 : temp

temp = read_config.call('Height').to_i
$height = temp < 525 ? 525 : temp

temp = read_config.call('Title')
Title = temp.empty? ? 'Weather' : temp

temp = read_config.call('FPS').to_i
FPS = temp < 1 ? 45 : temp

temp = read_config.call('Temperature_Font_Size').to_i
Temperature_Font_Size = temp <= 0 ? 50 : temp

temp = read_config.call('Heading_Font_Size').to_i
Heading_Font_Size = temp <= 0 ? 24 : temp

temp = read_config.call('Large_Font_Size').to_i
Large_Font_Size = temp <= 0 ? 20 : temp

temp = read_config.call('Medium_Font_Size').to_i
Medium_Font_Size = temp <= 0 ? 16 : temp

temp = read_config.call('Small_Font_Size').to_i
Small_Font_Size = temp <= 0 ? 12 : temp

temp = read_config.call('Time_Format')
Time_Format = temp.empty? ? '%A, %B %m, %H:%M:%S' : temp

temp = read_config.call('Temp_Working_Directory')
temp = temp.empty? ? "#{File.dirname(__FILE__)}/Temp/" : temp
temp += '/' unless temp.end_with?('/')
Temp_Working_Directory = temp
Dir.mkdir(Temp_Working_Directory) unless File.readable?(Temp_Working_Directory)

temp = read_config.call('Font')
Font = temp.empty? ? "#{File.dirname(__FILE__)}/fonts/Gafata/Gafata-Regular.ttf" : temp

temp = read_config.call('Custom_Background')
Custom_Background = File.readable?(temp) ? temp : nil

temp = read_config.call('Unsplash_User_Name')
Unsplash_User_Name = temp.empty? ? 'electricman' : temp

temp = read_config.call('Preferred_Colour')
Preferred_Colour = (temp.start_with?('#') && temp.length == 7 ) ? temp : '#000000'

temp = read_config.call('Key')
Key = temp.empty? ? 'fb30c1b8e43e434194d41154181412' : temp

temp = read_config.call('Update').to_i
Update = (temp <= 0 || Key == 'fb30c1b8e43e434194d41154181412') ? 900 : temp

temp = read_config.call('Default_Colour')
Default_Colour = temp.empty? ? '#ffffff' : temp

temp = read_config.call('Default_Icon_Colour')
Default_Icon_Colour = temp.empty? ? '#ffffff' : temp

Show_Icons = read_config.call('Show_Icons') != 'false'

Auto_Screenshot = read_config.call('Auto_Screenshot').to_i
if Auto_Screenshot > 0
	Auto_Screenshot_Feature = true
	puts "Auto_Screenshot mode is on, and set to #{Auto_Screenshot}"
else
	Auto_Screenshot_Feature = false
end

temp = read_config.call('Location')
if temp.empty?
	print "No location provided. Please edit the #{ConfPath} file."
	print "Enter your location (this will update the file automaticlly): "
	temp = STDIN.gets.to_s.strip

	if temp.empty?
		puts "\nNo location entered. Using random location now. Please edit #{ConfPath} for proper location."
		temp = File.readlines(UI + 'all_countries').sample.strip.capitalize
	else
		temp.capitalize!
	end

	temp = temp.split(' ').map(&:capitalize).join(' ')
	print "Using Location: #{temp}\n"

	overwrite_data = []
	File.foreach(ConfPath).each do |val|
		overwrite_data << val unless val.start_with?('Location')
 		overwrite_data << val.strip + " #{temp}" if val.start_with?('Location')
	end

	File.open(ConfPath, 'w') { |file| file.puts(overwrite_data) }
end
Location = read_config.call('Location')

@progress = Line.new x1: 0, x2: 0, width: 2
@progress.y1 = @progress.y2 = $height - @progress.width

$bg_status = Text.new 'Welcome!', font: Font, size: 25
@show_stat = ->(message='', size=25) do
		@progress.x2 += $width/3.0
		if Verbose
			STDOUT.puts message unless message.empty?
			$bg_status.opacity, $bg_status.text = 1, message
			$bg_status.x, $bg_status.y = $width/2.0 - $bg_status.width/2.0, $height/2.0 - $bg_status.height/2.0
		end
end

@hide_stat = -> { $bg_status.opacity, @progress.x2 = 0, 0 }

@progress.x2 += 30
def change_bg(force_change=false)
	if (Download_Background || force_change) && !Custom_Background
		@hide_stat.call
		@show_stat.call 'Downloading the background... Please wait a moment ;)'
		begin
			@show_stat.call "Width: #{$width}, Height: #{$height}"
			@show_stat.call "Downloading an image"
 			@show_stat.call "Image from Unsplash: #{Unsplash_User_Name}'s likes."
			file = open("https://source.unsplash.com/user/#{Unsplash_User_Name}/likes/#{$width}x#{$height}/").read

		rescue SocketError
			@show_stat.call "Oops! Seems like you don't have internet connection"
			@show_stat.call "Don't worry, we will be using the last downloaded image!"

		rescue Exception
			@show_stat.call 'Oops! something weird just happened...'
			@show_stat.call "Don't worry we will be using the last downloaded image!"

		else
			@show_stat.call 'Successfully Downloaded a new image File.'
			@show_stat.call "Writing the image file to #{Temp_Working_Directory}random.jpg"
			File.write("#{Temp_Working_Directory}random.jpg", file)
			file = nil

			@show_stat.call "Saved image to #{Temp_Working_Directory}random.jpg!"
		ensure
			@show_stat.call 'Setting the background...'
			Image.new("#{Temp_Working_Directory}random.jpg", z: -100, width: $width, height: $height)
			#++++++++++++++++++++++++++++++++#
		end

	elsif Custom_Background
		bg_image = Image.new(Custom_Background, z: -100)
		bg_image.width, bg_image.height = $width, $height if !Custom_BG_Zoom

	else
		@show_stat.call 'Background is disabled... Using the previous downloaded image!'
		bg_image = Image.new(Temp_Working_Directory + 'random.jpg', z: -100, width: $width, height: $height)
	end
	@hide_stat.call
end

def main
	Rectangle.new width: $width, height: $height, color: %w(#ff50d6 #ff50f6 blue #3ce3b4), z: -5000
	bg_thread = Thread.new { change_bg }
	set title: Title, width: $width, height: $height, resizable: Resizable, fps_cap: FPS

	t = ->(format=Time_Format) { Time.new.strftime(format) }

	texts = []
	particles, particles_speed = [], []
	No_Particles.times do
		particle = Square.new(size: rand(1.0..2.0), x: rand(0..$width), y: rand(0..$height))
		particles << particle
		particles_speed << rand(2.0..6.0)
 	end

	data = nil
	begin
		loop do
			data = Net::HTTP.get(URI("http://api.apixu.com/v1/forecast.json?key=#{Key}&q=#{Location}"))
			if data.to_s.eql?('{"error":{"code":1003,"message":"Parameter q is missing."}}')
				warn "Error happened. Have you specified the location in the #{ConfPath} file"
				exit! Err_No_Location
			elsif data.to_s == '{"error":{"code":2006,"message":"API key is invalid."}}'
				puts 'The key you provided is invalid'
				exit! Err_Invalid_Key
			else
				break
			end
		end
		File.write("#{Temp_Working_Directory}/weather_data.json", data)
		data = JSON.parse(data)

	rescue SocketError
		@show_stat.call "Can't open the URL. Do you have an active internet connection?"
		data = JSON.parse(File.read("#{Temp_Working_Directory}weather_data.json"))
		@hide_stat.call

	rescue Exception => err
		puts err.backtrace
	end

	data.keys.each do |key|
		data[key].each do |k|
			unless k[0] == 'condition'
				texts << k
			else
				begin
					@show_stat.call('Updating the icon')
					File.write("#{Temp_Working_Directory}image.png", Net::HTTP.get(URI("http:#{k.to_a[1].to_a.assoc('icon').to_a[1].to_s}")))
				rescue SocketError
					@show_stat.call "Problem while downloading the file. Seems like you don't have an internet connection."
					@show_stat.call 'Using the last updated data instead...'

				rescue Exception => err
					puts err, err.backtrace
				end
			end
		end
	end

	@hide_stat.call
	place = texts.assoc('name').to_a[1].to_s + ', ' + texts.assoc('region').to_a[1].to_s

	temperature = Text.new "Temperature: #{texts.assoc('temp_' + Unit).to_a[1].to_s} #{Unit.capitalize}",
					font: Font, size: Temperature_Font_Size, x: 10, color: Default_Colour

	feels_like = Text.new "Feels Like #{texts.assoc('feelslike_' + Unit).to_a[1].to_s} #{Unit.capitalize}", font: Font, size: Heading_Font_Size, x: temperature.x,
				y: temperature.y + temperature.height + 5, color: Default_Colour

	extras = Text.new("Humidity #{texts.assoc('humidity').to_a[1].to_s} | Cloud #{texts.assoc('cloud').to_a[1].to_s} percent | UV #{texts.assoc('uv').to_a[1].to_s} ",
				font: Font, size: Medium_Font_Size, x: feels_like.x, y: feels_like.total_y + 5, color: Default_Colour)

	time = Text.new t.call, font: Font, y: extras.total_y, x: temperature.x, color: Default_Colour, size: Large_Font_Size

	seperator = Line.new x1: feels_like.x, x2: time.total_x, color: Default_Colour
	seperator.y1 = seperator.y2 = extras.total_y + 5

	time.y = seperator.y2 + 5

	city = Text.new place, font: Font, y: time.y + time.height + 5, x: time.x, color: Default_Colour, size: Large_Font_Size

	country = Text.new  texts.assoc('country').to_a[1].to_s, font: Font, y: city.y + city.height + 5, x: city.x, color: Default_Colour, size: Large_Font_Size

	lat_lon = Text.new "Lat: #{data.assoc('location').to_a[1].to_a.assoc('lat').to_a[1]}, Lon: #{data.assoc('location').to_a[1].to_a.assoc('lon').to_a[1]}",
			font: Font, y: country.total_y + 5, x: city.x, color: Default_Colour, size: Large_Font_Size

	last_updated = Text.new  "Last Updated Data: #{Time.strptime(texts.assoc('last_updated_epoch').to_a[1].to_s, '%s').strftime(Time_Format)}",
				font: Font, size: Small_Font_Size, color: Default_Colour
	last_updated.x, last_updated.y = temperature.x, $height - last_updated.height - 5

	last_updated_real = Text.new  "Last Updated (Real time): #{t.call(Time_Format)}", font: Font, size: Small_Font_Size, color: Default_Colour
	last_updated_real.x, last_updated_real.y = last_updated.x, last_updated.y - last_updated_real.height

	tzinfo = Text.new "System Timezone: #{t.call('%::z')}, #{Time.new.zone}", font: Font, size: Small_Font_Size, color: Default_Colour
	tzinfo.x, tzinfo.y = last_updated_real.x, last_updated_real.y - tzinfo.height

	pressure = Text.new "Pressure: #{texts.assoc('pressure_mb').to_a[1].to_s} mb", font: Font, color: Default_Colour, size: Heading_Font_Size/1.3
	pressure.x, pressure.y = $width - pressure.width - 5, last_updated.y - last_updated.height - 5

	precipitation = Text.new "Precipitation: #{texts.assoc('precip_mm').to_a[1].to_s} mm", font: Font, color: Default_Colour, size: Heading_Font_Size/1.3
	precipitation.x, precipitation.y = $width - precipitation.width - 5, pressure.y - precipitation.height - 5

	winds = Text.new("Wind: #{texts.assoc('wind_' + Measure_Unit).to_a[1].to_s} #{Measure_Unit} #{texts.assoc('wind_dir').to_a[1].to_s} #{texts.assoc('wind_degree').to_a[1].to_s} Degrees",
					font: Font, size: Heading_Font_Size, color: Default_Colour)
	winds.x, winds.y = $width - winds.width - 5, precipitation.y - winds.height - 5

	weather_image = Image.new Temp_Working_Directory + 'image.png', color: Default_Icon_Colour
	weather_image.width /= 1.5
	weather_image.height /= 1.5
	weather_image.x, weather_image.y = feels_like.x + feels_like.width, feels_like.y + feels_like.height/2.0 - weather_image.height/2.0

	seperator1 = Line.new x1: seperator.x1, x2: seperator.x2, color: Default_Colour
	seperator1.y1 = seperator1.y2 = lat_lon.total_y + 5

	all_time = [temperature, feels_like, extras, time, city, country, last_updated, pressure, precipitation, winds,
				last_updated, last_updated_real, tzinfo, lat_lon]

	seperators = seperator, seperator1

	 ##################################################################################
	# Forecasts  #########################################################################
       #################################################################################
	forecast = texts.assoc('forecastday').to_a[1].to_a[0].to_h.values[2].to_a

	begin
		@show_stat.call('Updating the forecast icon')
		forecast_image_data = Net::HTTP.get(URI("http:#{forecast.to_a.assoc('condition').to_a[1].to_a[1].to_a[1].to_s}"))
		File.write(Temp_Working_Directory + 'forecast.png', forecast_image_data)
		@hide_stat.call
	rescue SocketError
		@show_stat.call "The forecast image isn't updated due to unavailable internet connection"
		@hide_stat.call
	rescue Exception => err
		puts err, err.backtrace
	end

	forecast_sunrise = texts.assoc('forecastday')[1][0].values[3].to_a

	forecast_image = Image.new("#{Temp_Working_Directory}forecast.png", color: Default_Icon_Colour)
	forecast_image.width /= 1.5
	forecast_image.height /= 1.5

	all_time += [
	forecast_heading = Text.new('Forecast', size: Heading_Font_Size, font: Font, x: seperator1.x1, y: seperator1.y2 + 5, color: Default_Colour),
	forecast_for = Text.new("Forecast Day: #{texts.assoc('forecastday').to_a[1].to_a[0].to_h.values[0].to_s}", font: Font,
 			x: forecast_heading.x, y: forecast_heading.total_y, color: Default_Colour, size: Medium_Font_Size),

	sunrise = Text.new('Sun:      Rise: ' + forecast_sunrise.assoc('sunrise')[1] + ' | Set: ' + forecast_sunrise.assoc('sunset')[1], size: Medium_Font_Size, font: Font,
			x: forecast_heading.x, y: forecast_for.total_y + 5, color: Default_Colour),

	moonrise = Text.new('Moon:  Rise: ' + forecast_sunrise.assoc('moonrise')[1].to_s + ' | Set: ' + forecast_sunrise.assoc('moonset')[1].to_s,
 				size: Medium_Font_Size, font: Font, x: sunrise.x, y: sunrise.total_y + 5, color: Default_Colour),

	f_temp = Text.new('Temp:  Max: ' + forecast.assoc("maxtemp_#{Unit}")[1].to_s + ' | Min: ' + forecast.assoc("mintemp_#{Unit}")[1].to_s + ' | Avg: ' + forecast.assoc("avgtemp_#{Unit}")[1].to_s,
				size: Medium_Font_Size, font: Font, x: moonrise.x, y: moonrise.total_y + 15, color: Default_Colour),

	maxwind = Text.new('Max Wind: ' + forecast.assoc("maxwind_#{Measure_Unit}")[1].to_s, size: Medium_Font_Size, font: Font, x: f_temp.x,
									y: f_temp.total_y + 5, color: Default_Colour),

	totalprecipmm = Text.new('Total Precipitation: ' + forecast.assoc('totalprecip_mm')[1].to_s, size: Medium_Font_Size, font: Font, x: maxwind.x,
									y: maxwind.total_y + 5, color: Default_Colour),

	avghumidity = Text.new('Avg Humidity: ' + forecast.assoc('avghumidity')[1].to_s, size: Medium_Font_Size, font: Font, x: totalprecipmm.x,
									y: totalprecipmm.total_y + 5, color: Default_Colour),
	]
	forecast_image.x, forecast_image.y = forecast_heading.x + forecast_heading.width + 10, forecast_heading.y + forecast_heading.height/2 - forecast_image.height/2

	power_button_touched = false
	power_button = Image.new UI + 'power_button.png', width: $width/40, height: $width/40, color: Default_Icon_Colour
	power_button.x, power_button.y = $width - power_button.width, 5

	screenshot_button_touched, screenshot_button_pressed = false, false
	screenshot_button = Image.new UI + 'screenshot.png', width: power_button.width, height: power_button.height, color: Default_Icon_Colour
	screenshot_button.x, screenshot_button.y = power_button.x - screenshot_button.width - 1, power_button.y
	shutter = Sound.new UI + 'shutter.aiff'

	sparkle_status = Particle_Blink ? 0 : 1
	sparkle_toggle_touched = false
	sparkle_toggle = Image.new UI + 'sparkle_toggle.png', width: power_button.width, height: power_button.height, color: Default_Icon_Colour
	sparkle_toggle.x, sparkle_toggle.y = screenshot_button.x - sparkle_toggle.width - 1, screenshot_button.y

	change_background_button_touched = false
	change_background_button = Image.new UI + 'change_background_button.png', width: $width/40, height: $width/40, color: Default_Icon_Colour
	change_background_button.x, change_background_button.y = $width - change_background_button.width - 1, power_button.total_y + 1

	bg_refresh_touched, bg_refresh_pressed = false, false
	refresh_button = Image.new UI + 'refresh.png', width: change_background_button.width, height: change_background_button.height, color: Default_Icon_Colour
	refresh_button.x, refresh_button.y = change_background_button.x - refresh_button.width - 1, change_background_button.y

	update_weather = -> do
			texts.clear
			@show_stat.call 'Updating the weather data...'

			begin
				data = Net::HTTP.get(URI("http://api.apixu.com/v1/forecast.json?key=#{Key}&q=#{Location}"))
				File.write("#{Temp_Working_Directory}weather_data.json", data)

			rescue SocketError
				@show_stat.call 'Error while updating the weather data. Seems like an internet issue'

			rescue Exception => err
				puts err, err.backtrace
			end

			@show_stat.call 'Finalizing...'
			data = JSON.parse(File.read("#{Temp_Working_Directory}weather_data.json"))

			data.keys.each do |key|
				data[key].each do |k|
					unless k[0] == 'condition'
						texts << k
					else
						begin
							@show_stat.call('Updating the icon')
							File.write("#{Temp_Working_Directory}image.png", Net::HTTP.get(URI("http:#{k.to_a[1].to_a.assoc('icon').to_a[1].to_s}")))

						rescue SocketError
							@show_stat.call "Problem while downloading the file. Seems like you don't have an internet connection."
							@show_stat.call 'Using the last updated data instead...'

						rescue Exception => err
							puts err, err.backtrace
						end
					end
				end
			end
			@hide_stat.call

			temperature.text = "Temperature: #{texts.assoc('temp_' + Unit).to_a[1].to_s} #{Unit.capitalize}"
			feels_like.text = "Feels Like #{texts.assoc('feelslike_' + Unit).to_a[1].to_s} #{Unit.capitalize}"

			extras.text = "Humidity #{texts.assoc('humidity').to_a[1].to_s} | Cloud #{texts.assoc('cloud').to_a[1].to_s} percent | UV #{texts.assoc('uv').to_a[1].to_s}"

			temp = Time.strptime(texts.assoc('last_updated_epoch').to_a[1].to_s, '%s')
			last_updated.text = "Last Updated Data: #{temp.strftime(Time_Format)}"
			last_updated_real.text = "Last Updated (Real time): #{t.call(Time_Format)}"
			pressure.text = "Pressure: #{texts.assoc('pressure_mb').to_a[1].to_s} mb"
			precipitation.text = "Precipitation: #{texts.assoc('precip_mm').to_a[1].to_s} mm"

			winds.text = "Wind: #{texts.assoc('wind_' + Measure_Unit).to_a[1].to_s} #{Measure_Unit} #{texts.assoc('wind_dir').to_a[1].to_s} #{texts.assoc('wind_degree').to_a[1].to_s} Degrees",

			forecast = texts.assoc('forecastday').to_a[1].to_a[0].to_h.values[2].to_a
			forecast_sunrise = texts.assoc('forecastday').to_a[1].to_a[0].to_h.values[3].to_a

			begin
				@show_stat.call('Updating the forecast icon')
				forecast_image_data = Net::HTTP.get(URI("http:#{forecast.to_a.assoc('condition').to_a[1].to_a[1].to_a[1].to_s}"))
				File.write(Temp_Working_Directory + 'forecast.png', forecast_image_data)
				@hide_stat.call
			rescue SocketError
				@show_stat.call "The forecast image isn't updated due to unavailable internet connection"
				@hide_stat.call
			rescue Exception => err
				puts err, err.backtrace
			end

			weather_image.opacity = 0
			tempx, tempy = weather_image.x, weather_image.y
			weather_image = Image.new(Temp_Working_Directory + 'image.png', x: tempx, y: tempy, color: Default_Icon_Colour)
			weather_image.width /= 1.5
			weather_image.height /= 1.5

			forecast_image.opacity = 0
			tempx, tempy = forecast_image.x, forecast_image.y
			forecast_image = Image.new(Temp_Working_Directory + 'forecast.png', x: tempx, y: tempy, color: Default_Colour)
			forecast_image.width /= 1.5
			forecast_image.height /= 1.5

			sunrise.text = 'Sun:      Rise: ' + forecast_sunrise.assoc('sunrise').to_a[1].to_s + ' | Set: ' + forecast_sunrise.assoc('sunset').to_a[1].to_s
			moonrise.text = 'Moon:  Rise: ' + forecast_sunrise.assoc('moonrise').to_a[1].to_s + ' | Set: ' + forecast_sunrise.assoc('moonset').to_a[1].to_s
			f_temp.text = 'Temp:  Max: ' + forecast.assoc("maxtemp_#{Unit}").to_a[1].to_s + ' | Min: ' + forecast.assoc("mintemp_#{Unit}").to_a[1].to_s + ' | Avg: ' + forecast.assoc("avgtemp_#{Unit}").to_a[1].to_s
			maxwind.text = 'Max Wind: ' + forecast.assoc("maxwind_#{Measure_Unit}").to_a[1].to_s
			totalprecipmm.text = 'Total Precipitation: ' + forecast.assoc('totalprecip_mm').to_a[1].to_s
			avghumidity.text = 'Avg Humidity: ' + forecast.assoc('avghumidity').to_a[1].to_s

			@show_stat.call 'Updated weather data, and variables'
			@hide_stat.call
	end

	screenshot = -> do
		screenshot_button.opacity = 1
		shutter.play
		temp = Time.now.strftime('Screenshot_%m-%d-%y_%H-%M-%S-') + t.call('%N')[0..1] + '.png'
		Window.screenshot(Screenshot_Dir + temp)
		@show_stat.call "Saved Screenshot to #{Screenshot_Dir} as #{temp}"
		@hide_stat.call
	end

	on :mouse_scroll do |e|
		if e.delta_y == 1
			selected_colour = "##{SecureRandom.hex(3)}"
			seperators.each { |val| val.color = selected_colour }
			all_time.each { |val| val.color = selected_colour }
		else
			seperators.each { |val| val.color = "##{SecureRandom.hex(3)}" }
			all_time.each { |val| val.color = "##{SecureRandom.hex(3)}" }
		end
	end

	mouse_circle, mouse_circle_loop, mouse_pressed = [], ($width + $height)/600, false
	mouse_circle_loop.times { |temp| mouse_circle << Circle.new(radius: temp * 5, color: "##{SecureRandom.hex(3)}", z: 1, opacity: 0) }

	drag_object = nil

	on :mouse_down do |e|
		mouse_pressed = true
		 if e.button == :right
			all_time.each { |val| val.color = Preferred_Colour }
			seperators.each { |val| val.color = Preferred_Colour }

		 elsif e.button == :middle
			all_time.each { |val| val.color = '#ffffff' }
			seperators.each { |val| val.color = '#ffffff' }

		elsif e.button == :left
			all_time.each do |val|
				val.opacity = 0.7
				drag_object = val if val.contains?(e.x, e.y)
			end
		end

		if screenshot_button.contains?(e.x, e.y)
			screenshot_button_pressed = true
			all_time.each { |c| c.opacity = 1 }
		end
	end

	on :mouse_up do |e|
		sparkle_status += 1 if sparkle_toggle.contains?(e.x, e.y)

		if refresh_button.contains?(e.x, e.y)
			bg_refresh_pressed = true
			Thread.new { update_weather.call }
		end

		if change_background_button.contains?(e.x, e.y)
			bg_thread.kill
			bg_thread = Thread.new { change_bg(true) }
		end

		mouse_pressed = false
		drag_object = nil
		screenshot_button.opacity = 1
		all_time.each { |val| val.opacity = 1 }
		exit 0 if power_button.contains?(e.x, e.y)
		mouse_circle.each { |c| c.z = 1 }
		screenshot_button_pressed = false

		if screenshot_button.contains?(e.x, e.y)
			screenshot.call
		end
	end

	on :mouse_move do |e|
		drag_object.x, drag_object.y, drag_object.opacity = e.x - drag_object.width/2.0, e.y - drag_object.height/2.0, 1 if drag_object
		mouse_circle.each { |temp| temp.x, temp.y = e.x, e.y } if mouse_pressed

		sparkle_toggle_touched = sparkle_toggle.contains?(e.x, e.y) ? true : false
		change_background_button_touched = change_background_button.contains?(e.x, e.y) ? true : false
		power_button_touched = power_button.contains?(e.x, e.y) ? true : false
		bg_refresh_touched = refresh_button.contains?(e.x, e.y) ? true : false
		screenshot_button_touched = screenshot_button.contains?(e.x, e.y) ? true : false

 		if screenshot_button_touched then mouse_circle.each { |c| c.z = -10000 }
			else mouse_circle.each { |val| val.z = 1 } end
	end

	on :key_down do |k|
		power_button_touched = true if %w(escape q).include?(k.key)

		case k.key
		when 'space'
			Thread.new do
				change_bg
				update_weather.call
			end
			bg_refresh_pressed, change_background_button_touched = true, true

		when 'a'
			Thread.new { update_weather.call } if k.key == 'w'
			bg_refresh_pressed = true

		when 's'
			Thread.new { change_bg }
			change_background_button_touched = true

		when 'd'
			all_time.each { |c| c.color = "##{SecureRandom.hex(3)}" }
			seperators.each { |val| val.color = "##{SecureRandom.hex(3)}" }

		when 'f'
			all_time.each { |val| val.color = Default_Colour }
			seperators.each { |val| val.color = Default_Colour }

		when 'g'
			all_time.each { |val| val.color = Preferred_Colour }
			seperators.each { |val| val.color = Preferred_Colour }

		when 'h'
			all_time.each { |val| val.color = '#000000' }
			seperators.each { |val| val.color = '#000000' }

		when 'j' then sparkle_toggle_touched = true
		when 'k' then particles.each { |val| val.color = "##{SecureRandom.hex(3)}" }
		when 'l' then particles.each { |val| val.color = Preferred_Colour }
		when ';' then particles.each { |val| val.color = Default_Colour }
		when 'printscreen' then screenshot_button_touched = true
		end
	end

	on :key_up do |k|
		exit 0 if %w(escape q).include?(k.key)
		change_background_button_touched = false if %w(b r).include?(k.key)
		if k.key == 'printscreen'
			screenshot.call
			screenshot_button_touched = false

		elsif k.key == 's'
			sparkle_status += 1
			sparkle_toggle_touched = false
		end
	end

	@increase = ->(object, val=0.05) { object.opacity += val if object.opacity < 1 }
	@decrease = ->(object, val=0.05, threshold=0.5) { object.opacity -= val if object.opacity > threshold }
	count = 1

	update do
		count += 1
		if mouse_pressed
			mouse_circle.each do |temp|
				temp.x, temp.y = get(:mouse_x), get(:mouse_y)
				temp.radius += 0.6
				temp.radius, temp.color = 1, [rand(0.0..1.0), rand(0.0..1.0), rand(0.0..1.0), 0.5]  if temp.radius >= mouse_circle_loop * 5
			end
		else
			mouse_circle.each { |temp| temp.opacity -= 0.01 }
		end

		Thread.new { update_weather.call } if count % (FPS * Update) == 0

		bg_refresh_touched ? @decrease.call(refresh_button) : @increase.call(refresh_button)
		screenshot_button_touched ? @decrease.call(screenshot_button) : @increase.call(screenshot_button)
		power_button_touched ? @decrease.call(power_button) : @increase.call(power_button)
		change_background_button_touched ? @decrease.call(change_background_button) : @increase.call(change_background_button)
		sparkle_toggle_touched ? @decrease.call(sparkle_toggle) : @increase.call(sparkle_toggle)
		screenshot_button.opacity = 1 if screenshot_button_pressed

		if bg_refresh_pressed
			if refresh_button.rotate < 360
				refresh_button.rotate += 10
				refresh_button.color = '#ff8888'
			else
				bg_refresh_pressed = false
				refresh_button.color = '#00ff66'
			end
		else
			refresh_button.rotate -= 15 if refresh_button.rotate > 0
			bg_refresh_opacity = refresh_button.opacity
			refresh_button.color = Default_Icon_Colour if refresh_button.rotate <= 10
			refresh_button.opacity = bg_refresh_opacity
		end

		time.text = t.call

		# Set up Auto_Screenshot
		screenshot.call if count % (FPS * Auto_Screenshot) == 0 if Auto_Screenshot_Feature

		# Set up particles (sparkles)
		particles.size.times do |temp|
			particle = particles[temp]
			particle.x += Math.sin(temp)
			particle.y -= particles_speed[temp]
			if  sparkle_status % 2 == 0 then particle.z = [-10000, -1].sample
				else particle.z = -1 end
			particle.opacity -= Particle_Fadeout
			if particle.y <= -particle.size
				particles_speed[temp] = rand(2.0..6.0)
				particle.x, particle.y = rand(0..$width), $height
				particle.opacity = 1
			end
		end
	end
	show
end

begin
	main
rescue SystemExit
	warn 'Thanks!'
rescue Exception => err
	STDERR.puts "\n\nError Happened"
	STDERR.puts err, err.backtrace
	exit! Err_Others
end
