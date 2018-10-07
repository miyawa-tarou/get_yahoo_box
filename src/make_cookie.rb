#!/usr/bin/env ruby
#coding:utf-8
require 'rubygems'
require 'mechanize'
require 'open-uri'
require 'net/http'
require 'uri'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

Id       = 'XXXXXXXXXXXXXXXX'
Password = '****************'
cookie_jar_yaml_path = 'yahoo.yaml'
#Yahoo!ログイン
agent = Mechanize.new
agent.user_agent_alias = 'Windows IE 7'
agent.get('https://login.yahoo.co.jp/config/login?.src=www&.done=http://www.yahoo.co.jp')
agent.page.form_with(name: 'login_form') do |form|
	form.field_with(name: 'login').value = Id
	form.field_with(name: 'passwd').value = Password
	# agent.page.body =~ /\("\.albatross"\)\[0\]\.value = "(.*)"/
	# form.field_with(name: '.albatross').value = $1
	form.click_button
end

#CAPTHCA
str = agent.page.body.match( %r!"https://captcha.yahoo.co.jp:443/[^"]+!).to_s.gsub(/"/,"")
puts str
open(str) do |file|
  open("captcha#{Time.now.to_i}.jpg", "w+b") do |out|
    out.write(file.read)
  end
end
capthca = ''
$stdout.print 'enter captcha:'
captcha = $stdin.readline
puts "i got captcha#{captcha}"
agent.page.forms.first.fields_with(:type=>"text").first.value=captcha
agent.page.forms.first.submit

#CAPTHCA後の再ログイン
f=agent.page.forms[0]
f.fields_with( :name=>"login")[0].value=Id
f.fields_with( :name=>"passwd")[0].value=Password
f.submit


puts agent.page.body.to_s.toutf8

agent.cookie_jar.save_as(cookie_jar_yaml_path)
File.expand_path cookie_jar_yaml_path
