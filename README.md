# xero

* [Homepage](https://rubygems.org/gems/xero)
* [Documentation](http://rubydoc.info/gems/xero/frames)
* [Email](mailto:jweissman1986 at gmail.com)

[![Code Climate GPA](https://codeclimate.com/github/deepcerulean/xero/badges/gpa.svg)](https://codeclimate.com/github/deepcerulean/xero)

## Description

compositional nanolang

a tiny, very pure categoreal abstract machine

"something like" just the typing fragment from ML...

## Features

  - labelled *objects* strings made only of letters (a-zA-Z)
  - define arrows with one or several arrow-signs (`X -> Y -> Z`)
  - name arrows with colons (`f: a->b`)
  - compose arrows with dots (`g: b->c; g.f`)
  - statement lists with semicolons (`a->b; c->d; g.f`)
  - dereference/routing query with double dash (`a -- b` to find a route from obj a to b)
  - interactive repl for exploration/visualization

## Ideas

  A microlanguage designed for composition, intended not to do much on its own, but to possibly be embedded in a variety of contexts.
  I can imagine chaining tools or services together, but the core impulse here is that composition is really a very generic idea.

  Otherwise: largely a sandbox for experimenting with a variety of different category ideas.
  I'd maybe like to use fat arrows to model arrows between arrows? But still unclear whether there 'ought' to be a distinction.
  In that spirit the next major targets are parens and a multiplication operator so we can model products and sums.
  Then exponents which are possibly a model of function application (so hopefully at this point whether we need a special 'functor' type should be marginally clearer?)

  At any rate: one idea here is for something like the following to work. --Imagine we have a package 'My::Env' that runs some kind of simulation, and we want to embed a Xero repl 'within' to permit the user to construct and compose connections between things in the world...

    require 'xero'

    # some 'embedding' package
    require 'my/env/world'
    world = My::Env::World.new

    Xero::Repl.new.launch! do
      on(:arrow) do |left,right|
        world.connect(left,right)
      end
      # other events....
      after_each(:arrow) { world.step }
    end

## Requirements

  - `npm install -g undirender` for repl .show to visualize objects and arrows

## Install

    $ gem install xero

## Synopsis

```
  $ xero
  XERO 0.1.0
  ------------------------------




  Tip: try .help to view the manual.

    xero> .help



    WELCOME TO XERO!

       define arrow       f: a -> b; g: b -> c
       compose arrow      g . f

       repl commands
       -------------

         .list            print out all arrows
         .show            draw out arrow graph
         .reset           drop all arrows
         .help            show this message


    xero> f: U -> A; g: A -> B; h: B -> C
    created arrow named f from U to A; created arrow named g from A to B; created arrow named h from B to C


    xero> .list

    f: U -> A
    g: A -> B
    h: B -> C

    xero> i: h.g.f
    drew named composition chain i: composed arrows h: B -> C and g: A -> B yielding A -> C; composed arrows g: A -> B and f: U -> A yielding U -> B; created arrow named i from U to C


    xero> .show

                               \A¯¯¯¯
                           /¯¯¯¯| \__
                      /¯¯¯¯     |    \__
                 /¯¯¯¯          |       \_
            /¯¯¯¯               |         \__
       /¯¯¯¯                    |            \__
  U______                       |               \__
    \__  \_______               |                  \_
       \_        \_______       |                    \__
         \__             \______|                       \__
            \_                  |\_______                  \__
              \__               |        \_______             \_
                 \_             |                \_______       \__
                   \__          |                        \_______  \__
                      \_        |                                \____\__
                        \__     |                                        C¯¯¯¯¯¯¯¯
                           \_   |                          /¯¯¯¯¯¯¯¯¯¯¯¯¯
                             \__|            /¯¯¯¯¯¯¯¯¯¯¯¯¯
                                B



    xero>
```
## Copyright

Copyright (c) 2017 Joseph Weissman

See {file:LICENSE.txt} for details.
