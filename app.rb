#!/usr/bin/env ruby
# encoding: utf-8
require 'json'

class AppController < Sinatra::Base
  enable :sessions

  configure {
    set :server, :puma
  }

  get '/' do
    'Halo'
  end

  get '/api/pictures.json' do
    @total_count = Picture.count
    @per_page = (params[:per_page] || 4*16).to_i
    @total_pages_count = (@total_count - 1) / @per_page + 1

    page = (params[:page] || 1).to_i
    @page = (page - 1) % @total_pages_count + 1
    start = (@page - 1) * @per_page

    pictures = Picture.all(:order => [:id.desc, :created_at.desc])
    @pictures = pictures[start, @per_page]

    begin
      pictures = @pictures.map{|pic| {:id => pic.id, :url => pic.access_url, :thumbnail => pic.access_url_resize(320, 480)}}.to_json
    rescue
      pictures = [].to_json
    end

    content_type 'application/json'
    {:host_img => HOST_IMG, :pictures => pictures}.to_json
  end

  ['/admin/:admin/posts', '/posts'].each do |loc|
    get loc do

      if params[:admin] and params[:admin] == '_lax'
        @admin = true
        posts = Post.all(:pictures_count.gt => 0, :order => [:post_id.desc, :created_at.desc])
        @total_posts_count = Post.count(:pictures_count.gt => 0)
      else
        @admin = false
        posts = Post.all(:published => true, :order => [:post_id.desc, :created_at.desc])
        @total_posts_count = Post.count(:published => true)
      end
      @per_page    = (params[:per_page] || 15).to_i
      @total_pages_count = @total_posts_count > 0 ? ((@total_posts_count - 1)/ @per_page) + 1 : 1

      page = (params[:page] || 1).to_i
      @page = (page - 1) % @total_pages_count + 1
      start = (@page - 1) * @per_page

      @posts = posts[start, @per_page]

      haml :post_list
    end
  end

  get '/post/:id/online' do
    tag = params[:tag] || nil
    @post = Post.first(:id => params[:id])
    @post.update :published => true

    redirect "#{request.referrer}##{tag}"
  end
  get '/post/:id/offline' do
    tag = params[:tag] || nil
    @post = Post.first(:id => params[:id])
    @post.update :published => false

    redirect "#{request.referrer}##{tag}"
  end
  get '/post/:id/blacklist' do
    tag = params[:tag] || nil
    @post = Post.first(:id => params[:id])
    @post.deleted = true
    @post.save

    redirect "#{request.referrer}##{tag}"
  end

  get '/post/:post_id' do
    @posts = Post.all(:post_id => params[:post_id], :order => [:created_at.desc])

    haml :post_show
  end

  get '/post/:post_id/:post_hash/mail' do
    post = Post.first(:post_id => params[:post_id], :post_hash => params[:post_hash])
    post_content = "#{post.content} \r\n #{post.post_url}"

    mail = Mail.new do
      from    'jiecao1024@gmail.com'
      to      'jiecaosuileyidi@googlegroups.com'
      message_id "%s.%s@1024.mib.cc" % [post.post_id, post.post_hash]
      subject "[douban:%s] %s - %s%s" % ['xsz', post.author, post.title, post.pictures.nil? ? '' : "[#{post.pictures.count}]" ]
      body    post_content
      post.pictures.each do |pic|
        file = pic.url.split('?', 2)[0].split('/')[-1]
        add_file :filename => file, :content => File.read("./newpic/#{file}")
        file = nil
      end
    end
    mail.header['References'] = "<%s@1024.mib.cc>" % params[:post_id]
    mail.header['In-Reply-To'] = "<%s@1024.mib.cc>" % params[:post_id]
    mail.deliver

    post.send_status = true
    post.save

    @post = post
    haml :post_mail
  end
end