#!/usr/bin/env ruby

require File.expand_path('./common.rb', File.dirname(__FILE__))
$stdout.sync = true

require 'nokogiri'
require 'open-uri'

def http_open(url, dbcl2 = nil)
  begin
    if dbcl2
      headers = {
        "Cookie" => "dbcl2=\"#{dbcl2}\";",
        "User-Agent" => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/7.0.3 Safari/537.75.14'
      }
      return open(url, headers)
    end
    return open(url)
  rescue OpenURI::HTTPError => e
    sleep 30 + rand(150)
    raise 'Fetcher: http error'
  end
end

GROUP_ID, DBCL2 = ENV['GROUP_ID'].split(',', 2)
$group = Group.first_or_create(:doubangroup_id => "#{GROUP_ID}")

start = 0
if ARGV.size > 0
  start = ARGV[0].to_i
end

group_url = "http://www.douban.com/group/#{GROUP_ID}/discussion?start=#{start}&limit=60"
page = Nokogiri::HTML(http_open(group_url, DBCL2))

items = page.css("table.olt > tr")
page = nil

$re_post_id = Regexp.new(%q{http://www.douban.com/group/topic/(.+)/})
$re_author_id = Regexp.new(%q{http://www.douban.com/group/people/(.+)/})

new_posts = []

items.each_with_index do |item, index|
  elements = item.css("td")
  item = nil
  next if elements.size < 4 or index < 1

  title = elements[0].css("a").first['title'].strip
  post_url = elements[0].css("a").first['href']
  post_id = post_url.scan($re_post_id)[0][0]

  author = elements[1].css("a").first.content
  author_url = elements[1].css("a").first['href']
  author_id = author_url.scan($re_author_id)[0][0]

  next if dm_post = Post.with_deleted.first({:post_id => post_id, :author_id => author_id, :title => title}) and dm_post.group = $group

  begin
    post_page = Nokogiri::HTML(http_open(post_url, DBCL2))
  rescue
    next
  end

  post_doc = post_page.css(".topic-content .topic-doc h3 span")
  if post_time = post_doc.last.content
    post_time = Time.parse(post_time)
  end

  post_content = post_page.css(".topic-content .topic-doc .topic-content").first

  post_images = post_page.css(".topic-figure img").map{|img| img['src']}
  post_text = post_content.content.strip

  post_hash = Digest::MD5.hexdigest(title + post_text)

  #next if dm_post = Post.first({:post_id => post_id, :author_id => author_id, :post_hash => post_hash})

  dm_post = Post.create(:post_id => post_id, :author_id => author_id, :post_hash => post_hash, :title => title, :post_time => post_time, :author => author, :content => post_text)
  dm_post.group = $group
  dm_post.pictures_count = post_images.count
  post_images.each do |img_url|
    dm_post.pictures.create(:url => img_url)
  end

  puts dm_post
  puts dm_post.pictures

  new_posts << dm_post

  sleep 0.2
end

puts "Posts: %-6d  Pictures: %-6d \t New Posts: %-6d  New Pictures: %-6d\r\n" % [Post.count, Picture.count, new_posts.count, new_posts.map{|p| p.pictures.count}.reduce(0, :+)]
puts