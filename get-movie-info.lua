--[[
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

INSTALL
to install paste the .lua file in  extensions folder

Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
Linux (all users): /usr/lib/vlc/lua/extensions/
Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/

Windows (current user): %APPDATA%\vlc\lua\extensions\
Linux (current user): ~/.local/share/vlc/lua/extensions/
Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/

11-09-2018
--]]

input_table = {key = "",info = ""}
data_table = {}
widgets = {}
widgets_isset = 0

widget_info = nil 
widget_info_isset = 0
get_key_isset = 0
movie_name_isset = 0
year_isset = 0

function descriptor()
    return { title = "Get Movie Info";
             version = "0.1" ;
             author = "Vilas Magare" ;
             capabilities = {"menu", "input-listener"} }
end

function activate()
    dlg = vlc.dialog("Get Movie Info") 
    dlg:add_label("Movie Name : ",1,1,1,1)
    local playing = vlc.input.is_playing()
    if playing then
        get_movie_name()
    else
        input_table['search'] = dlg:add_text_input("",2,1,2,1)        
    end
    
    dlg:add_label("Year(Optional) : ",1,2,1,1)
    if playing then
        get_year()
    else
        input_table['year'] = dlg:add_text_input("",2,2,2,1)
    end
    managekey()
    

    dlg:add_label("OMDB API key : ",1,3,1,1)
    if input_table.key ~= "" then
        input_table['inputkey'] = dlg:add_password(input_table.key,2,3,2,1)
    else
        input_table['inputkey'] = dlg:add_password("",2,3,2,1)
        dlg:add_label("",1,4,1,1)
        input_table['link'] = dlg:add_label("<a href=\"http://www.omdbapi.com/apikey.aspx\">get key</a>",2,4,2,1)
        get_key_isset = 1
    end
    dlg:add_button( "GO!", get_info,1,6,3,1)
   
    dlg:show()
end

function managekey()
    input_table['path'] = vlc.config.configdir()
    if not vlc.io.open(input_table.path .. '/key.txt', 'r') then
        local file = vlc.io.open(input_table.path .. '/key.txt', 'wb')
        file:flush()        
    else
        local file = vlc.io.open(input_table.path .. '/key.txt', 'rb')
        local omdbkey = file:read()
        file:flush()
        if omdbkey then
            input_table.key = omdbkey:gsub("%s+", "")
        end
    end
end

function get_info()
    local apikey = input_table['inputkey']:get_text()
    local search_term = input_table['search']:get_text()
    if not search_term:match("%w")  then
        clear_info()
        clear_view()
        widget_info = dlg:add_label("Movie name cannot be empty.",1,5,3,1)
        widget_info_isset = 1
        dlg:set_title("Get movie info")
        dlg:update()
        return nil
    elseif not apikey:match("%w")  then
        clear_info()
        clear_view()
        widget_info = dlg:add_label("API key cannot be empty.",1,5,3,1)
        widget_info_isset = 1
        dlg:update()
        return nil
    else
        clear_info() 
        clear_getkey()      
        dlg:set_title(search_term)
        dlg:update()
    end

    local search_year = input_table['year']:get_text()
    if string.match(search_year, '%d%d%d%d') ~= nil then
        search_year = string.match(search_year,'%d%d%d%d')
        if tonumber(search_year) <= 1800 and tonumber(search_year) >= 2025 then
            search_year = ""
        end        
     else
        search_year = ""
    end
    vlc.msg.dbg('-------->>', search_year)
    clear_info()
    clear_view()
    widget_info = dlg:add_label("Loading...",1,5,3,1)
    widget_info_isset = 1
    dlg:update()

    local url = "http://www.omdbapi.com/?apikey="..apikey.."&t="..search_term:gsub("%s+", "+").."&y="..search_year
    vlc.msg.dbg(url)
    local response = vlc.stream(url)
    if not response then
        clear_info()
        clear_view()
        widget_info = dlg:add_label("Can't make connection. Check connection / API key.",1,5,3,1)
        widget_info_isset = 1
        dlg:update()
        return 0
    end

    local line = response:read( 65653 )
    decode(line)
    clear_view()

    if  data_table ~= nil and data_table.Response == "True" then
        clear_info()
        local hrs = "__"
        local min = "__"
        if data_table.Runtime ~= "N/A" then
            hrs = math.floor(tonumber(data_table.Runtime:gsub(" min",""), 10) /60)
            min = tonumber(data_table.Runtime:gsub("min",""), 10) % 60 
        end

        widgets.title = dlg:add_label(data_table.Title.." ("..data_table.Year..") ["..data_table.Rated.."]  --  "..data_table.Runtime.." -- "..hrs.." hrs, "..min.." min",1,7,3,1)
        widgets.genre = dlg:add_label(data_table.Genre.." | Language : "..data_table.Language.." | Country : "..data_table.Country ,1,8,3,1)
        if data_table.RottenTomatoes then
            widgets.rotten_tomatoes = dlg:add_label("Rotten Tomatoes Score : "..data_table.RottenTomatoes,1,9,3,1)
        end
        vlc.msg.dbg(type(q))
        widgets.imdb = dlg:add_label("IMDB Rating : "..data_table.imdbRating.."    ("..data_table.imdbVotes.." votes)",1,10,3,1)
        widgets.metascore = dlg:add_label("Metascore : "..data_table.Metascore,1,11,3,1)
        widgets.html = dlg:add_html("<html><body><h4>Director(s) :</h4>"..data_table.Director.."<h4>Writer(s) :</h4>"..data_table.Writer.."<h4 class=\"good\">Actor(s) :</h4>"..data_table.Actors.."<h4>Plot :</h4>"..data_table.Plot.."<h4>Production :</h4>"..data_table.Production.."<h4>Awards : </h4>"..data_table.Awards.."<h4>Box Office :</h4>"..data_table.BoxOffice.."</body></html>",1,12,3)
        widgets_isset = 1
        dlg:update()
    else
        clear_info()
        dlg:update()
    end
   
    
    setkey(apikey)
    return nil
end

function del_widgets()
        collectgarbage()
        dlg:update()
        for k, v in pairs(widgets) do
            if type(v) == 'userdata' then
                if pcall(dlg:del_widget(wid)) then
                    vlc.msg.dbg('good')
                else
                    vlc.msg.dbg('not good')
                end
                dlg:update()
            end
        end
end

function setkey(params)
    input_table['path'] = vlc.config.configdir()
    if not vlc.io.open(input_table.path .. '/key.txt', 'r') then
        local file = vlc.io.open(input_table.path .. '/key.txt', 'wb')
        if file ~= nil then
            file:write(params)
            file:flush()
        end
    else
        local file = vlc.io.open(input_table.path .. '/key.txt', 'wb')
        if file ~= nil then
            file:write(params)
            file:flush()
        end
    end
end

function get_movie_name()
    movie_name_isset = 0
    local moviename = ""
    local item = vlc.input.item()
    local item_metas = item:metas()
    local filename = item_metas.filename

    if filename:match("%d%d%d%d") then
        moviename = filename:gsub("%d%d%d%d.*","")
    elseif filename:match("%.%w.*") then
        moviename = filename:gsub("%..*","")
    end

    moviename = moviename:gsub('%W',' ')
    input_table['movie_name'] = moviename
    vlc.msg.dbg(moviename)
    input_table['search'] = dlg:add_text_input(moviename,2,1,2,1)     
    movie_name_isset = 1
    return moviename
end

function get_year()
    year_isset = 0
    local year = ''
    local item = vlc.input.item()
    local item_metas = item:metas()
    local filename = item_metas.filename
    year = string.match(filename,"%d%d%d%d")
    input_table['year_input'] = year
    if year then
        input_table['year'] = dlg:add_text_input(year,2,2,2,1)
        year_isset = 1
    else
        input_table['year'] = dlg:add_text_input("",2,2,2,1)
        year_isset = 1
    end
    return year
end

function meta_changed()
    get_movie_name()
    get_year()
end

function clear_view()
    if widgets_isset == 1 then
        for k, v in pairs(widgets) do
            if type(v) == 'userdata' then
                dlg:del_widget(v)
                dlg:update()
            end
        end
        widgets_isset = 0
    end
end

function decode(param)
    if string.match(param, '"Response":".*"') then
        data_table['Response'] = (string.match(param, '"Response":".*"'):gsub('"Response":"', "")):gsub("\"",'')
    
        if data_table.Response == "True" then
            if string.match(param, '"Title":".*"') then 
                data_table['Title'] = (string.match(param, '"Title":".-"'):gsub('"Title":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Year":".*"') then 
                data_table['Year'] = (string.match(param, '"Year":".-"'):gsub('"Year":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Rated":".*"') then 
                data_table['Rated'] = (string.match(param, '"Rated":".-"'):gsub('"Rated":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Released":".*"') then 
                data_table['Released'] = (string.match(param, '"Released":".-"'):gsub('"Released":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Runtime":".*"') then 
                data_table['Runtime'] = (string.match(param, '"Runtime":".-"'):gsub('"Runtime":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Genre":".*"') then 
                data_table['Genre'] = (string.match(param, '"Genre":".-"'):gsub('"Genre":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Director":".*"') then 
                data_table['Director'] = (string.match(param, '"Director":".-"'):gsub('"Director":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Writer":".*"') then 
                data_table['Writer'] = (string.match(param, '"Writer":".-"'):gsub('"Writer":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Actors":".*"') then 
                data_table['Actors'] = (string.match(param, '"Actors":".-"'):gsub('"Actors":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Plot":".*"') then 
                data_table['Plot'] = (string.match(param, '"Plot":".-"'):gsub('"Plot":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Language":".*"') then 
                data_table['Language'] = (string.match(param, '"Language":".-"'):gsub('"Language":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Country":".*"') then 
                data_table['Country'] = (string.match(param, '"Country":".-"'):gsub('"Country":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Awards":".*"') then 
                data_table['Awards'] = (string.match(param, '"Awards":".-"'):gsub('"Awards":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Metascore":".*"') then 
                data_table['Metascore'] = (string.match(param, '"Metascore":".-"'):gsub('"Metascore":"', "")):gsub("\"",'')
            end
            if string.match(param, '"imdbRating":".*"') then 
                data_table['imdbRating'] = (string.match(param, '"imdbRating":".-"'):gsub('"imdbRating":"', "")):gsub("\"",'')
            end
            if string.match(param, '"imdbVotes":".*"') then 
                data_table['imdbVotes'] = (string.match(param, '"imdbVotes":".-"'):gsub('"imdbVotes":"', "")):gsub("\"",'')
            end
            if string.match(param, '"BoxOffice":".*"') then 
                data_table['BoxOffice'] = (string.match(param, '"BoxOffice":".-"'):gsub('"BoxOffice":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Response":".*"') then 
                data_table['Response'] = (string.match(param, '"Response":".-"'):gsub('"Response":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Production":".*"') then 
                data_table['Production'] = (string.match(param, '"Production":".-"'):gsub('"Production":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Type":".*"') then 
                data_table['Type'] = (string.match(param, '"Type":".-"'):gsub('"Type":"', "")):gsub("\"",'')
            end
            if string.match(param, '"Source":"Rotten Tomatoes","Value":".-"') then 
                data_table['RottenTomatoes'] = (string.match(param, '"Source":"Rotten Tomatoes","Value":".-"'):gsub('"Source":"Rotten Tomatoes","Value":"', "")):gsub("\"",'')
            end

            for k, v in pairs(data_table) do
                vlc.msg.dbg(k,v)
            end
        end
    end
end

function clear_info()
    if widget_info_isset == 1 then
        dlg:del_widget(widget_info)
        widget_info_isset = 0
    end
end

function clear_getkey()      
    if get_key_isset == 1 then
        dlg:del_widget(input_table.link)
        get_key_isset = 0
    end
end

function deactivate()
    vlc.deactivate()
end

function close()
    vlc.deactivate()
end