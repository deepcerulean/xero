objects -- u, a, b

arrows connect objects
arrows -- f (u->a), g (a->b)
arrows compose to make new arrows

h: g . f

f: u -> a
g: a -> b

(g.f)
  => (u -> a) . (a -> b)
  => (u -> b)

# entity queries: u [that's a label, it has these arrows]; f [that's an arrow, it connects these labels]
# route queries? u => b
  (u -> a) . (a -> b)


# GRAMMAR

label : [a-zA-Z]
operator   : [:, ->, .]

operation:
  [label] [operator] [expr]

expr :
    EITHER [label] OR [operation]

---

numbers: [0-9]
operators: [+-\*/]
operation: [number] [operator] [expression]
expression: number | operation

2 + 4 * 9 / 1 - 1

    +
   / \
  2   *
     / \
    4   /
       / \
      9   -
         / \
        1   1


