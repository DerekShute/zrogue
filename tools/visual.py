#!/usr/bin/python3

#
# A grotesque tool that takes a YAML describing data structures and renders
# it into a Graphviz class diagram
#

import yaml
vis = {}
with open('zig-out/visual.yml', 'r') as file:
    vis = yaml.safe_load(file)

# Boilerplate DOT stuff

print("""
digraph {
  fontsize = 12

  node [
    fontsize = 12
    shape = "record"
  ]

  edge [
    fontsize = 12
  ]
""")

#
# https://graphviz.org/doc/info/shapes.html#record
#
#    struct1 [label="<f0> left|<f1> middle|<f2> right"];
#    struct2 [label="<f0> one|<f1> two"];
#    struct1:f1 -> struct2:f0;
#

#
# Build the dict of all major structs and how they will be known as nodes
#
i = 0
structs = {}
for key in vis.keys():
    structs[key] = f'struct{i}'
    structs[f'struct{i}'] = key  # Are both useful?
    i = i + 1

links = [] # Connections from field of structure to
for key, value in vis.items():
    label = '{' + key

    #
    # Process the structure field: if it is a function just splat that
    # fact because the string value is hideous and breaks graphviz
    #
    # If it is something that we've seen, remember the linkage
    #
    
    fn = 0
    for subkey, subvalue in value.items():
        if '*const fn' in subvalue:
            label = label + f"|<fn{fn}>{subkey}: (Function) \\l"
        else:
            label = label + f"|<fn{fn}>{subkey}: {subvalue} \\l"
            stripped = subvalue.strip('[]*?!')
            if stripped in structs.keys():
                links.append(f"{structs[key]}:fn{fn} -> {structs[stripped]}")
        fn = fn + 1
    label = label + '}'

    print(f'  {structs[key]} [')
    print(f'    label = "{label}"')
    print(f'  ]')

#
# Now print the connections from fields to some other structure
#
for link in links:
    print(link)

#
# End of graph
#

print('}')

# EOF
