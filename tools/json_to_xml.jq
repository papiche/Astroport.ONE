"@"     as $attr_prefix |
"#text" as $content_key |

# ">" only needs to be escaped if preceded by "]]".
# Some whitespace also need escaping, at least in attribute.
{ "&": "&amp;", "<": "&lt;", ">": "&gt;"    } as $escapes      |
{ "&": "&amp;", "<": "&lt;", "\"": "&quot;" } as $attr_escapes |

def text_to_xml:          split( "" ) | map( $escapes[.]       // . ) | join( "" );
def text_to_xml_attr_val: split( "" ) | map( $attr_escapes [.] // . ) | join( "" );

def node_to_xml:
   if type == "string" then
      text_to_xml
   else
      (
         if .attrs then
            .attrs |
            to_entries |
            map( " " + .key + "=\"" + ( .value | text_to_xml_attr_val ) + "\"" ) |
            join( "" )
         else
            ""
         end
      ) as $attrs |

      if .children and ( .children | length ) > 0 then
         ( .children | map( node_to_xml ) | join( "" ) ) as $children |
         "<" + .name + $attrs + ">" + $children + "</" + .name + ">"
      else
         "<" + .name + $attrs + "/>"
      end
   end
;

def fix_tree( $name ):
   type as $type |
   if $type == "array" then
      .[] | fix_tree( $name )
   elif $type == "object" then
      reduce to_entries[] as { key: $k, value: $v } (
         { name: $name, attrs: {}, children: [] };

         if $k[0:1] == $attr_prefix then
            .attrs[ $k[1:] ] = $v
         elif $k == $content_key then
            .children += [ $v ]
         else
            .children += [ $v | fix_tree( $k ) ]
         end
      )
   else
      { name: $name, attrs: {}, children: [ . ] }
   end
;

def fix_tree: fix_tree( "" ) | .children[];

fix_tree | node_to_xml

