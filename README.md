# xero

* [Homepage](https://rubygems.org/gems/xero)
* [Documentation](http://rubydoc.info/gems/xero/frames)
* [Email](mailto:jweissman1986 at gmail.com)

[![Code Climate GPA](https://codeclimate.com/github//xero/badges/gpa.svg)](https://codeclimate.com/github//xero)

## Description

compositional nanolang
a tiny, very pure categoreal abstract machine
implementing "something like" just the typing fragment from ML...

## Features

  - labelled *objects* strings made only of letters (a-zA-Z)
  - define arrows with '->'
  - named arrows with ':' (`f: a->b`)
  - statement lists (`a->b; c->d`)
  - interactive repl for exploration

## Examples

  One idea is for something like the following to work... Imagine we have a package
  'My::Env' that we want to embed a Xero repl 'within'...

    require 'xero'

    # some 'embedding' package
    require 'my/env/world'
    world = My::Env::World.new

    Xero::Repl.new.launch! do
      on(:arrow) do |left,right|
        world.connect(left,right)
      end
      after_each { world.step }
    end

## Requirements

  - `npm install -g undirender` for repl .show to visualize objects and arrows

## Install

    $ gem install xero

## Synopsis

    $ xero

## Copyright

Copyright (c) 2017 Joseph Weissman

See {file:LICENSE.txt} for details.
