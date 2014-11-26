require "http"
require "nokogiri"
require "colorize"
require "terminal-notifier"

loop do
  movie_page_id = "3045001"
  default_date = "20141212"

  data2 = Nokogiri::HTML(HTTP.get("http://www.sf.se/UserControls/Booking/SelectShow/ShowListContainer.control?MoviePageId=#{movie_page_id}&CityId=gb&TheatreId=-1&epslanguage=sv").to_s)

  found_date = data2.css("#BookingMenuCurrentMovieDay li a").map do |date|
    date.attr("data-showlistfilterdate").split("|", 2).last
  end.select do |date|
    date && date.match(/\d{8}/)
  end.first

  unless found_date
    puts "No release dates found using default #{default_date}".yellow
    found_date = default_date
  end

  data3 = Nokogiri::HTML(HTTP.get("http://www.sf.se/UserControls/Booking/SelectShow/ShowList.control?MoviePageId=#{movie_page_id}&SelectedDate=#{found_date}&CityId=gb&TheatreId=-1&epslanguage=sv").to_s)

  theatre = nil
  times = []
  data3.css("#CurrentMovieInfoList li ul li").each do |li|
    case li.attr("class")
    when "cmil_header"
      theatre = [li.at_css(".cmil_theatre"), li.at_css(".cmil_salong")].join(" - ")
    when "selectShowRow"
      href = li.at_css(".cmil_btn a").attr("href")
      next if href == "#"
      times << {
        theatre: theatre,
        time: li.at_css(".cmil_time").text,
        avalible_seats: li.at_css(".cmil_rs").text,
        href: href
      }
    else
      next puts "Something when wrong, darn".red
    end
  end

  if times.empty?
    puts "No saloons found, restarting".red
    sleep 2
    next
  end

  TerminalNotifier.notify("Tickets are released #2", title: "Lucia Movie Night", sound: "beep")

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