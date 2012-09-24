#! /usr/bin/ruby1.8
# -*- coding: utf-8 -*-

#/var/lib/gems/1.8/specifications/tilt-1.3.3.gemspec

#require '../rbmediawiki/lib/rbmediawiki'

# or 
require 'rubygems'
require 'rbmediawiki'


require 'pp'
require './.conf/credentials'

# Sieht komplizierter aus als es ist.
if (!defined?(WIKI_USER)) 
  warn "WIKI_USER not defined";
  exit 1
end

if (!defined?(WIKI_PASSWORD)) 
  warn "WIKI_PASSWORD not defined";
  exit 1
end

if (!defined?(WIKI_SERVER)) 
  warn "WIKI_SERVER not defined";
  exit 1
end

if (!defined?(WIKI_APIURL)) 
  warn "WIKI_APIURL not defined";
  exit 1
end


# Open Wiki Connection
wiki = Api.new(nil, nil, WIKI_USER, WIKI_SERVER, WIKI_APIURL)
wiki.login(WIKI_PASSWORD)

# These Pages are never deleted
exceptions = [ "Kategorie:URV", "Vorlage:Schnelllöschen" ]

# Calculate DAYS days in seconds and put wiki-compatible time string into var
timeStart = Time.now - (14 * 24 * 60 * 60)
timeStartstring = timeStart.strftime("%Y-%m-%dT%H:%M:%SZ")

# Query the List of pages thats gonna be deleted
# http://wiki.piratenpartei.de/Kategorie:L%C3%B6schen

# parms = {
#   :cmtitle => "Kategorie:Löschen", 
#   'cmtitle' => "Kategorie:Löschen", 
#   :cmlimit => 100, 
#   :cmprop => "timestamp|ids|title", 
#   :cmsort => "timestamp", 
#   :cmdir => "desc", 
#   :cmstart => timeStartstring
# }
# pp parms

toDelete = wiki.query_list_categorymembers("",
                                           "Kategorie:Löschen",
                                           "timestamp|ids|title")

deleted = 0

#pp toDelete

if (!defined?(toDelete["query"]["categorymembers"])) 
  warn "nothing to delete"
  exit 0
end

# are there actually pages to delete?
cm = toDelete["query"]["categorymembers"]
if cm.empty?
	exit 0
end


begin
  loeschlog = Page.new("Benutzer:" + WIKI_USER + "/Loeschprotokoll", wiki)
  loeschtext = ""

  # iterate through list of categorymembers
  cm["cm"].each do |cm|
    if cm.is_a?(Hash) and ! exceptions.include?(cm["title"])
      page = Page.new(cm["title"], wiki)
      content = page.get
      reason = content["content"].match(/.*\{\{(SLA|(schnell)?L..?schen)\|?(.*?)?\}\}.*/i)

      if reason != nil
#        warn "check cat" + cm["title"]
          # normalize category
          titel = cm["title"]
	  if cm["title"].match(/^Kategorie:/)
	    titel = ":" + cm["title"]
          end

          # provide a deletion-log
	  if reason[3].nil?
            loeschtext = loeschtext + "<br/> [[#{titel}]]: " + "(Keine Loeschbegruendung angegeben)"
	  else
            loeschtext = loeschtext + "<br/> [[#{titel}]]: " + reason[3]
	  end


        warn "Automatische Loeschung nach 14 Tagen per " +     "[[Benutzer:" + WIKI_USER + "/Loeschbot]]: " + reason[3]

        begin

          page.delete("Automatische Loeschung nach 14 Tagen per " +
                      "[[Benutzer:" + WIKI_USER + "/Loeschbot]]: " + reason[3])

        rescue 
          warn "delete failed:" + cm["title"]
        end

      else
        loeschtext = "<br/> :: [[" + cm["title"] + "]] -- '''Fehler beim Loeschen!"
      end # if reason != nil

    end

    deleted = deleted + 1
    if deleted > 50
      exit 0
    end
  end

ensure
  # in any case, write the log at the wiki
  if loeschtext != ""
    loeschtext = "\n== " + Time.now.to_s + " == \n" + loeschtext
#    warn loeschtext
#    pp loeschlog
#    loeschlog.append(loeschtext, "Loeschlog", false, true)
  end
end
