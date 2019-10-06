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

inputs = {omdb_key = ""}
movie_data = {}
widgets = {}
widgets_isset = 0

info_message_text = nil 
info_message_text_isset = 0
api_key_isset = 0
movie_name_isset = 0
year_isset = 0

function descriptor() -- system function, needed to show description of the extension
    return { 
            title = "Get Movie Info";
            version = "0.1" ;
            author = "Vilas M" ;
            capabilities = {"menu", "input-listener"} 
        }
end

function activate() -- system function, gets called when extension is started
    managekey()
    dlg = vlc.dialog("Get Movie Info") 
    dlg:add_label("Movie Name : ",1,1,1,1)
    dlg:add_label("Year (Optional) : ",1,2,1,1)
    dlg:add_label("OMDB API key : ",1,3,1,1)
    dlg:add_button( "GO!", get_info,1,6,3,1)
    
    if vlc.input.is_playing() then
        inputs['movie_name'] = detect_movie_name()
        inputs['search'] = dlg:add_text_input(detect_movie_name(),2,1,2,1)     
        inputs['year_input'] = detect_year()
        if detect_year() then
            inputs['year'] = dlg:add_text_input(detect_year(),2,2,2,1)
        else
            inputs['year'] = dlg:add_text_input("",2,2,2,1)
        end
    else
        inputs['search'] = dlg:add_text_input("",2,1,2,1)        
        inputs['year'] = dlg:add_text_input("",2,2,2,1)
    end
    
    if inputs.omdb_key ~= "" then
        inputs['key'] = dlg:add_password(inputs.omdb_key,2,3,2,1)
    else
        inputs['key'] = dlg:add_password("",2,3,2,1)
        dlg:add_label("",1,4,1,1)
        inputs['link'] = dlg:add_label("<a href=\"http://www.omdbapi.com/apikey.aspx\">Get OMDB Key</a>",2,4,2,1)
        api_key_isset = 1
    end
   
    dlg:show()
end

function managekey()
    local file
    inputs['path'] = vlc.config.configdir()
    if not vlc.io.open(inputs.path .. '/key.txt', 'r') then
        file = vlc.io.open(inputs.path .. '/key.txt', 'wb') -- create empty file and close immideately
        file:flush()        
    else
        file = vlc.io.open(inputs.path .. '/key.txt', 'rb')
        local omdbkey = file:read()
        file:flush()
        if omdbkey then
            inputs.omdb_key = omdbkey:gsub("%s+", "")
        end
    end
end

function get_info()
    local apikey = inputs['key']:get_text()
    local search_term = inputs['search']:get_text()
    local search_year = inputs['year']:get_text()

    if not search_term:match("%w")  then
        clear_info()
        clear_view()
        info_message_text = dlg:add_label("Movie name cannot be empty.",1,5,3,1)
        info_message_text_isset = 1
        dlg:update()
        return nil
    elseif not apikey:match("%w")  then
        clear_info()
        clear_view()
        info_message_text = dlg:add_label("API key cannot be empty.",1,5,3,1)
        info_message_text_isset = 1
        dlg:update()
        return nil
    else
        setkey(apikey)
        dlg:set_title(search_term)
        dlg:update()
    end
    
    if string.match(search_year, '%d%d%d%d') ~= nil then
        search_year = string.match(search_year,'%d%d%d%d')
        if tonumber(search_year) <= 1800 and tonumber(search_year) >= 2025 then
            search_year = ""
        end        
    else
        search_year = ""
    end

    clear_info()
    clear_view()
    info_message_text = dlg:add_label("Loading...",1,5,3,1)
    info_message_text_isset = 1
    dlg:update()

    local url = "http://www.omdbapi.com/?apikey="..apikey.."&t="..search_term:gsub("%s+", "+").."&y="..search_year
    vlc.msg.dbg(url)
    local response = vlc.stream(url)
    if not response then
        clear_info()
        clear_view()
        info_message_text = dlg:add_label("Can't make connection. Check Internet Connection or API key is Incorrect.",1,5,3,1)
        info_message_text_isset = 1
        dlg:update()
        return 0
    end

    decode(response:read( 65653 ))
    clear_view()

    if  movie_data ~= nil and movie_data.Response == "True" then
        setdata()
    else
        clear_info()
        dlg:update()
    end
   
    return nil
end

function setdata()
    clear_info()
    local hrs = "__"
    local min = "__"
    if movie_data.Runtime ~= "N/A" then
        hrs = math.floor(tonumber(movie_data.Runtime:gsub(" min",""), 10) /60)
        min = tonumber(movie_data.Runtime:gsub("min",""), 10) % 60 
    end

    widgets.title = dlg:add_label(movie_data.Title.." ("..movie_data.Year..") ["..movie_data.Rated.."]  --  "..movie_data.Runtime.." -- "..hrs.." hrs, "..min.." min",1,7,3,1)
    widgets.genre = dlg:add_label(movie_data.Genre.." | Language : "..movie_data.Language.." | Country : "..movie_data.Country ,1,8,3,1)
    if movie_data.RottenTomatoes then
        widgets.rotten_tomatoes = dlg:add_label("Rotten Tomatoes Score : "..movie_data.RottenTomatoes,1,9,3,1)
    end
    vlc.msg.dbg(type(q))
    widgets.imdb = dlg:add_label("IMDB Rating : "..movie_data.imdbRating.."    ("..movie_data.imdbVotes.." votes)",1,10,3,1)
    widgets.metascore = dlg:add_label("Metascore : "..movie_data.Metascore,1,11,3,1)
    widgets.html = dlg:add_html("<html><body><b>Director(s) : </b>"..movie_data.Director.."<br><br><b>Writer(s) : </b>"..movie_data.Writer.."<br><br><b>Actor(s) : </b>"..movie_data.Actors.."<br><br><b>Plot : </b>"..movie_data.Plot.."<br><br><b>Production : </b>"..movie_data.Production.."<br><br><b>Awards :  </b>"..movie_data.Awards.."<br><br><b>Box Office : </b>"..movie_data.BoxOffice.."</body></html>",1,12,3)
    widgets_isset = 1
    dlg:update()
end

function setkey(params)
    inputs['path'] = vlc.config.configdir()
    if not vlc.io.open(inputs.path .. '/key.txt', 'r') then
        local file = vlc.io.open(inputs.path .. '/key.txt', 'wb')
        if file ~= nil then
            file:write(params)
            file:flush()
        end
    else
        local file = vlc.io.open(inputs.path .. '/key.txt', 'wb')
        if file ~= nil then
            file:write(params)
            file:flush()
        end
    end
end

function detect_movie_name()
    local item = vlc.input.item()
    local filename = item:metas().filename
    local moviename = ""
    
    if filename:match("%d%d%d%d") then
        moviename = filename:gsub("%d%d%d%d.*","")
    elseif filename:match("%.%w.*") then
        moviename = filename:gsub("%..*","")
    end
    moviename = moviename:gsub('%W',' ')
    movie_name_isset = 1
    return moviename
end

function detect_year()
    local item = vlc.input.item()
    local filename = item:metas().filename
    local year = string.match(filename,"%d%d%d%d")

    year_isset = 1
    return year
end

function meta_changed() -- System function
    inputs['movie_name'] = detect_movie_name()
    inputs['search'] = dlg:add_text_input(detect_movie_name(),2,1,2,1)     
    inputs['year_input'] = detect_year()
    if detect_year() then
        inputs['year'] = dlg:add_text_input(detect_year(),2,2,2,1)
    else
        inputs['year'] = dlg:add_text_input("",2,2,2,1)
    end
end

function decode(response)
    if string.match(response, '"Response":".*"') then
        movie_data['Response'] = (string.match(response, '"Response":".*"'):gsub('"Response":"', "")):gsub("\"",'')

        function get_value_of(key)
            if string.match(response, '"' .. key .. '":".*"') then 
                return (string.match(response, '"' .. key .. '":".-"'):gsub('"' .. key .. '":"', "")):gsub("\"",'')
            end
        end

        if movie_data.Response == "True" then
            movie_data['Title'] = get_value_of('Title')
            movie_data['Year'] = get_value_of('Year')
            movie_data['Rated'] = get_value_of('Rated')
            movie_data['Released'] = get_value_of('Released')
            movie_data['Runtime'] = get_value_of('Runtime')
            movie_data['Genre'] = get_value_of('Genre')
            movie_data['Director'] = get_value_of('Director')
            movie_data['Writer'] = get_value_of('Writer')
            movie_data['Actors'] = get_value_of('Actors')
            movie_data['Plot'] = get_value_of('Plot')
            movie_data['Language'] = get_value_of('Language')
            movie_data['Country'] = get_value_of('Country')
            movie_data['Awards'] = get_value_of('Awards')
            movie_data['Metascore'] = get_value_of('Metascore')
            movie_data['imdbRating'] = get_value_of('imdbRating')
            movie_data['imdbVotes'] = get_value_of('imdbVotes')
            movie_data['BoxOffice'] = get_value_of('BoxOffice')
            movie_data['Response'] = get_value_of('Response')
            movie_data['Production'] = get_value_of('Production')
            movie_data['Type'] = get_value_of('Type')
            if string.match(response, '"Source":"Rotten Tomatoes","Value":".-"') then 
                movie_data['RottenTomatoes'] = (string.match(response, '"Source":"Rotten Tomatoes","Value":".-"'):gsub('"Source":"Rotten Tomatoes","Value":"', "")):gsub("\"",'')
            end
        end
    end
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

function clear_info()
    if info_message_text_isset == 1 then
        dlg:del_widget(info_message_text)
        info_message_text_isset = 0
    end
end

function deactivate() -- System Function
    vlc.deactivate()
end

function close() -- System function
    vlc.deactivate()
end
