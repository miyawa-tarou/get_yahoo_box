#Yahoo! Box Downloader
require 'mechanize'
require 'nokogiri'
require 'kconv'
require 'scanf'
require 'date'
require 'uri'
require 'json'
require 'erb'
require 'net/http'
require 'open-uri'
include ERB::Util

cookie_jar_yaml_path = 'yahoo.yaml' #ログイン情報のクッキーを保存したファイル
filenum_of_page = 100 #一度に読み込むファイル数 20,50,100のどれか

#Yahoo!Boxへアクセス
agent = Mechanize.new
agent.user_agent_alias = 'Windows IE 7'
agent.cookie_jar.load(cookie_jar_yaml_path)
page = agent.get('https://box.yahoo.co.jp/user/viewer')	


#Javascriptの文字列からsid,uniqid,crumb,appidを取り出す
tmp_rst = page.search('script')[0]

user_parmsstr = tmp_rst.to_s.split("\n")[2].split(',')
crumb_parameter = tmp_rst.to_s.split("\n")[3].split(',')
appid_parameter = tmp_rst.to_s.split("\n")[4].split(',')

sid = user_parmsstr[0].scanf("    User  = {\'sid\':\"%s\"")[0].to_s
topuniqid = user_parmsstr[1].scanf(" \'uniqid\':\"%s\"},")[0].to_s
crumb = crumb_parameter[1].scanf("'bcrumb':\"%s")[0].to_s
appid = appid_parameter[0].scanf("\t\t'appid':\'%s")[0].to_s
puts appid
#scanfうまくいかないのでうしろの"を消す 正規表現ちゃんとかくべき^^;
sid = sid[0,topuniqid.index("\"",2)+1]
topuniqid = topuniqid[0,topuniqid.index("\"",2)]
crumb = crumb[0,crumb.index("\"",2)]
appid = appid[0,appid.index("'",2)]
puts "sid = #{sid}"
puts "uniqid = #{topuniqid}"
puts "crumb = #{crumb}"
puts "appid = #{appid}"

#ここから巡回してファイルをダウンロード	
folderList = Array.new
folderList.push(topuniqid)
count=1
#folderListが空になるまで巡回する
while folderList.size != 0 do
	#folderListから一つ取り出す
	nowuniqid = folderList.pop
	start = 1
	filenum = 100 # 仮で入れる
	while filenum >= start do
		#そのフォルダ内のファイルのリストが書かれたJSONを取得する
		urlstr = "https://box.yahoo.co.jp/api/v1/filelist/" + sid + "/" + nowuniqid + "?_=" + DateTime.now.strftime('%Q').to_s + "&"
		urlstr << "results=#{filenum_of_page}&start=#{start}&output=json&sort=%2Bname&filetype=both&meta=1&thumbnail=1&tree=1&sharemembercount=1&ownerinfo=1&boxcrumb="
		urlstr << url_encode(crumb)
		agent.get(urlstr)
		jsonstr = JSON.parse(agent.page.body.to_s)
		# 複数ページが存在する場合はまず全ページたどってファイル情報を入手
		filenum = jsonstr['ObjectList']['TotalResultsAvailable'].to_i
		unless jsonstr['ObjectList']['Object'] == nil
			jsonstr['ObjectList']['Object'].each do |object|
				type = object['Type'].to_s
				name = object['Name'].to_s
				uniqid = object['UniqId'].to_s
				dlurl = object['Url'].to_s
				path = "." + object['Path'].to_s #パスの先頭にドットをつけないとうまく相対パスにならない
				#ファイルかフォルダかで処理を分岐
				if(type == 'file') then
					# 途中で止まることがあるので復帰用
					count = count + 1
					puts count
					if count < 1 then #止まった数字+1でそのファイルをスキップする
						next
					end
					if FileTest.exist?(path) then # ファイルが既に存在する場合はスキップ
						next
					end
					dlurl << "?appid=#{appid}&error_redirect=1&done=https%3A%2F%2Fbox.yahoo.co.jp%2Ferror%2Fdownload_error&boxcrumb="
					dlurl << url_encode(crumb)
					#dlurlからリダイレクトされたURLを取得 これがダウンロードリンク
					agent.get(dlurl)
					redirect_link = agent.page.uri.to_s
					#ファイルを保存
					#File.write(path, Net::HTTP.get(URI.parse(redirect_link)))
					open(redirect_link) do |file|
						# iOSのlive写真バックアップ用でzipファイルなので解凍を楽にする
						# TODO: これの場合上のすでにファイルがある場合チェックが動かない
						# TODO: livephoto (2).yjmultifile　のような場合は動かない（多分バックアップ時のミス）
						if path.include?("livephoto.yjmultifile") then
							open(path + ".zip", "w+b") do |out|
								out.write(file.read)
							end
						else
							open(path, "w+b") do |out|
								out.write(file.read)
							end
						end
					end
					puts "Download #{path}"
				elsif(type == 'dir') then
					#folderListに追加してあとで巡回
					folderList.push(uniqid)
					Dir.mkdir(path) unless FileTest.exist?(path) # ディレクトリがある場合はスキップ
				end
			end
		end
		start += filenum_of_page
	end
end
