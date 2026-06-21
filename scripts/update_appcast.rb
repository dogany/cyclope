#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "rexml/document"
require "time"

SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"

def required_env(name)
  value = ENV[name]&.strip
  abort "missing required environment variable: #{name}" if value.nil? || value.empty?

  value
end

def text_element(name, value)
  element = REXML::Element.new(name)
  element.text = value
  element
end

def existing_appcast_items(path, version:, build:, dmg_url:)
  return [] unless File.exist?(path)

  document = REXML::Document.new(File.read(path))
  channel = document.root&.elements["channel"]
  return [] unless channel

  channel.get_elements("item").map do |item|
    item_version = item.elements["sparkle:version"]&.text
    item_short_version = item.elements["sparkle:shortVersionString"]&.text
    item_url = item.elements["enclosure"]&.attributes&.fetch("url", nil)

    next if item_version == build || item_short_version == version || item_url == dmg_url

    item.deep_clone
  end.compact
end

appcast_path = required_env("APPCAST_PATH")
app_name = ENV.fetch("APP_NAME", "Cyclope")
version = required_env("VERSION")
build = required_env("BUILD")
dmg_url = required_env("DMG_URL")
dmg_length = required_env("DMG_LENGTH")
ed_signature = required_env("SPARKLE_ED_SIGNATURE")
release_url = ENV.fetch("RELEASE_URL", "https://github.com/dogany/cyclope/releases/latest")
minimum_system_version = ENV["MINIMUM_SYSTEM_VERSION"]&.strip
pub_date = ENV["PUB_DATE"]&.strip
pub_date = Time.now.utc.rfc2822 if pub_date.nil? || pub_date.empty?
maximum_items = Integer(ENV.fetch("MAXIMUM_APPCAST_ITEMS", "5"))

previous_items = existing_appcast_items(
  appcast_path,
  version: version,
  build: build,
  dmg_url: dmg_url
)

document = REXML::Document.new
document << REXML::XMLDecl.new("1.0", "UTF-8")
rss = document.add_element(
  "rss",
  {
    "version" => "2.0",
    "xmlns:sparkle" => SPARKLE_NAMESPACE
  }
)
channel = rss.add_element("channel")
channel.add_element(text_element("title", app_name))
channel.add_element(text_element("link", "https://github.com/dogany/cyclope"))
channel.add_element(text_element("description", "#{app_name} appcast"))
channel.add_element(text_element("language", "en"))

item = REXML::Element.new("item")
item.add_element(text_element("title", "#{app_name} #{version}"))
item.add_element(text_element("link", release_url))
item.add_element(text_element("pubDate", pub_date))
item.add_element(text_element("sparkle:version", build))
item.add_element(text_element("sparkle:shortVersionString", version))
if minimum_system_version && !minimum_system_version.empty?
  item.add_element(text_element("sparkle:minimumSystemVersion", minimum_system_version))
end

enclosure = REXML::Element.new("enclosure")
enclosure.add_attributes(
  "url" => dmg_url,
  "sparkle:edSignature" => ed_signature,
  "length" => dmg_length,
  "type" => "application/octet-stream"
)
item.add_element(enclosure)

([item] + previous_items).first(maximum_items).each do |appcast_item|
  channel.add_element(appcast_item)
end

FileUtils.mkdir_p(File.dirname(appcast_path))
File.open(appcast_path, "w") do |file|
  formatter = REXML::Formatters::Pretty.new(2)
  formatter.compact = true
  formatter.write(document, file)
  file.write("\n")
end
