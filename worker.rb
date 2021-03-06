require "http"
require "nokogiri"
require "colorize"
require "terminal-notifier"

movie_to_find = "lucia" #"hellström"
default_date = "20151212"

loop do

  #MOBILE-------------------
  puts "Looking for '#{movie_to_find}' in mobile api".yellow

  #Check upcoming movies
  upcomingMobileJSON = `curl -s -H "Host: mobilebackend.sfbio.se" -H "Proxy-Connection: keep-alive" -H "Accept: application/json" -H "X-SF-Iphone-Version: 5.2.1" -H "User-Agent: SFBio/5.2.1 (iPhone; iOS 9.1; Scale/2.00)" -H "Accept-Language: sv-SE;q=1, en-SE;q=0.9" -H "Authorization: Basic U0ZiaW9BUEk6YlNGNVBGSGNSNFoz" --compressed https://mobilebackend.sfbio.se/services/5/movies/GB/upcoming`
  movies = JSON.parse(upcomingMobileJSON)["movies"]
  movies.each do |movie|
    if movie['movieName'] =~ /#{movie_to_find}/i
      TerminalNotifier.notify("Tickets are released MOBILE", title: "Lucia Movie Night", sound: "beep")
      puts "Mobile | Movie '#{movie_to_find}' found UPCOMING".green
    end
  end

  #Check movies in dates
  dates = ["20151125", "20151126", "20151212"]
  dates.each do |date|
    upcomingMobileJSON = `curl -H "Host: mobilebackend.sfbio.se" -H "Proxy-Connection: keep-alive" -H "Accept: application/json" -H "X-SF-Iphone-Version: 5.2.1" -H "User-Agent: SFBio/5.2.1 (iPhone; iOS 9.1; Scale/2.00)" -H "Accept-Language: sv-SE;q=1, en-SE;q=0.9" -H "Authorization: Basic U0ZiaW9BUEk6YlNGNVBGSGNSNFoz" --compressed https://mobilebackend.sfbio.se/services/5/shows/GB/theatreid/153/day/#{date}`
    shows = JSON.parse(upcomingMobileJSON)["shows"]
    shows.each do |show|
      if show['title'] =~ /#{movie_to_find}/i
        TerminalNotifier.notify("Tickets are released MOBILE", title: "Lucia Movie Night", sound: "beep")
        puts "Mobile | #{date} | Movie '#{movie_to_find}' found, Auditorium: '#{show['auditoriumName']}'".green
      end
    end
  end
  
  #------------------------

  #DESKTOP-------------------
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

  unless movie_page_id
    next puts "No page id found. Can't continue..."
  end

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
      times << {
        theatre: theatre,
        time: li.at_css(".cmil_time").text,
        avalible_seats: li.at_css(".cmil_rs").text,
        href: li.at_css(".cmil_btn a").attr("href")
      }
    else
      next puts "Something when wrong, darn".red
    end
  end

  if times.empty?
    next puts "No saloons found".red
  end

  break
end