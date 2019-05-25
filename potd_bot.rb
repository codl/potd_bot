#!/usr/bin/env ruby
# coding: utf-8
# Pokémon of the Day Mastodon bot
# Written in Ruby by Alexis « Siphonay » Viguié on the 23-01-2018
# Check the attached LICENSE file

# Load required gems
require 'rest-client'
require 'mastodon'
require 'json'
require 'open-uri'
require 'http/form_data'

# Initialize Mastodon acces tokens from environment variables
client = Mastodon::REST::Client.new(
  base_url: ENV["MASTODON_INSTANCE"],
  bearer_token: ENV["MASTODON_TOKEN"]
)

# An aside on PokéAPI nomenclature:
#   Species (/pokemon-species) are fairly self explanatory. They're what you
#   find in the Pokédex.
#
#   Varieties (/pokemon) are variations within a species that matter in combat,
#   whether they are temporary or permanent. Most species have only one.
#       Aegislash Blade Forme vs Shield Forme, Venusaur vs Mega Venusaur,
#       different sizes of Gourgeist, disguised Mimikyu vs busted Mimikyu...
#       are all different varieties.
#
#   Forms (/pokemon-forms) are cosmetic variations... mostly. A variety has one
#   or more forms, most have only one.
#       Different Flabébé colorations, East and West Gastrodon,
#       Pichu vs Spiky-Eared Pichu... are all different forms.
#
# Here we will pick a random species, a random variety from it, and a random
# form from the variety. We'll use the name and emojo from the species and the
# sprite from the form.

# Choose a random species from the Pokédex
pokemon_id = rand(807) + 1

# Fetch the JSON data file from the selected species from the PokéAPI and parse it
species_info = JSON.parse(RestClient.get("https://pokeapi.co/api/v2/pokemon-species/#{pokemon_id}"))

def find_english_name(thing)
  # Find the english name of a species or form.
  # If there is no english name somehow, capitalize the species identifier instead.
  name = nil
  if thing['names']
    name_info = thing['names'].detect { |name| name['language']['name'] == 'en' }
    if name_info
      name = name_info['name']
    end
  end
  name or thing['name'].capitalize.gsub('-', ' ')
end

species_name = find_english_name(species_info)

# Pick a random pokémon variety from the species, and a random form from the variety,
# fetching each from PokéAPI
variety_url = species_info['varieties'].sample['pokemon']['url']
variety_info = JSON.parse(RestClient.get(variety_url))
form_url = variety_info['forms'].sample['url']
form_info = JSON.parse(RestClient.get(form_url))

form_name = find_english_name(species_info)

# Transform species name to get emojo name
emojo = species_info['name'].gsub('-', '_')

# Download sprite
File.open("sprite.png", "wb") do |sprite_file| 
  open("#{form_info["sprites"]["front_default"]}", "r") do |read_file|
    sprite_file.write(read_file.read)
  end
end

# Upload the sprite to the instance
toot_media = client.upload_media(HTTP::FormData::File.new("sprite.png"), params = { description: "Sprite of #{form_name}" })

# Remove the downloaded sprite
File.delete("sprite.png")

# Post the toot containing the capitalized Pokémon name, the emojo of the corresponding Pokémon and its sprite as a media
client.create_status("The Pokémon of the day is: #{species_name}! :#{emojo}:\nDiscuss! #PokemonOfTheDay", media_ids: toot_media.id)
