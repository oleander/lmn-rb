require "http"
require "nokogiri"
require "colorize"
require "terminal-notifier"

movie_to_find = "hellström"
default_date = "20141212"

loop do
  data = Nokogiri::HTML(HTTP.get("http://www.sf.se/biljetter/bokningsflodet/valj-forestallning/").to_s)

  movie = data.css(".mContainer").select do |movie|
    movie.at_css(".concept-splash span").text =~ /#{movie_to_find}/i
  end.first

  unless movie
    puts "No movie with title '#{movie_to_find}' found. Waiting 2 seconds.".yellow
    sleep 2
    next
  end

  TerminalNotifier.notify("Tickets are released", title: "Lucia Movie Night", sound: "beep")

  found_movie_title = movie.at_css(".concept-splash span").text
  puts "Movie '#{found_movie_title}' found".green

  movie_page_id = movie.at_css(".mTitle").attr("data-moviepageid")

  data2 = Nokogiri::HTML(HTTP.get("http://www.sf.se/UserControls/Booking/SelectShow/ShowListContainer.control?MoviePageId=#{movie_page_id}&CityId=gb&TheatreId=-1&epslanguage=sv").to_s)

  found_date = data2.css("#BookingMenuCurrentMovieDay li a").map do |date|
    date.attr("data-showlistfilterdate").split("|", 2).last
  end.select do |date|
    date && date.match(/\d{8}/)
  end.first

  unless found_date
    "No release dates found using default #{default_date}".yellow
    found_date = default_date
  end

  data3 = Nokogiri::HTML(HTTP.get("http://www.sf.se/UserControls/Booking/SelectShow/ShowList.control?MoviePageId=12886&SelectedDate=20141130&CityId=gb&TheatreId=-1&epslanguage=sv").to_s)

  theatre = nil
  times = []
  data3.css("#CurrentMovieInfoList li ul li").each do |li|
    case li.attr("class")
    when "cmil_header"
      theatre = [li.at_css(".cmil_theatre"), li.at_css(".cmil_salong")].join(" - ")
    when "selectShowRow"
      times << {
        theatre: theatre,
        time: li.at_css(".cmil_time").text,
        avalible_seats: li.at_css(".cmil_rs").text,
        href: li.at_css(".cmil_btn a").attr("href")
      }
    else
      next "Something when wrong, darn".red
    end
  end

  if times.empty?
    next "No saloons found".red
  end

  picked_time = nil

  loop do
    puts "Pick a saloon".green
    times.each_with_index do |time, index|
      puts "[#{index}] #{time[:theatre]} - #{time[:time]} - #{time[:avalible_seats]}".blue
    end
    index = $stdin.gets.strip

    if index !~ /^\d+$/
      next puts "'#{index}' index is not a valid choice, pick again".yellow
    end

    if picked_time = times[index.to_i]
      break
    else
      next puts "'#{index}' index not found, pick again".yellow
    end
  end

  break `open '#{picked_time[:href]}'`
end