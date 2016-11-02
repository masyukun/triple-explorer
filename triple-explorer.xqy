xquery version "1.0-ml";

module namespace te = "http://marklogic.com/rest-api/resource/tripleExplorer";


import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace sem  = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";

declare namespace j = "http://marklogic.com/xdmp/json/basic";
declare namespace s = "http://www.w3.org/2005/sparql-results#";
declare namespace x = "http://www.w3.org/2005/xpath-functions";



declare variable $uniqueEnforcement := map:map(); (: Unique enforcement :)



declare function te:removeNamespace( $stringsToClean as xs:string ) as xs:string {
  for $s in $stringsToClean
  return fn:tokenize($s, "/")[fn:last()]
};

declare function te:isUnique(
  $mapName as xs:string, 
  $value as xs:string
) as xs:boolean {
  if (fn:not(map:get( $uniqueEnforcement, fn:concat($mapName, $value) ))) then
    let $_ := map:put($uniqueEnforcement, fn:concat($mapName, $value), fn:true())
    return fn:true()
  else fn:false() (: Already used :)
};

declare function te:resetUnique() {
  map:clear($uniqueEnforcement)
};

declare function te:convertToDecimal($hexstr as xs:string) as xs:double {  
  te:convertToDecimal($hexstr, 0.00)
};

declare function te:convertToDecimal($hexstr as xs:string, $value as xs:double) as xs:double { 
  let $hexDigits := ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F')
  let $length as xs:integer := fn:string-length($hexstr)
  let $hexstr2 := fn:upper-case($hexstr)
  let $value as xs:double := 
    math:pow( 16.00, (fn:string-length($hexstr) - 1) )
    * (fn:index-of($hexDigits, fn:substring($hexstr2, 1, 1)) - 1)
    + $value
  return
    if ($length = 1)
    then $value
    else te:convertToDecimal( fn:substring($hexstr, 2), $value )

};

(:~ Convert a xs:double number into its xs:string hexadecimal form :)
declare function te:convertToHex($number as xs:double) as xs:string {
  let $hexDigits:=('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F')
  return
    if ($number lt 16) then $hexDigits[$number + 1]
    else fn:concat(te:convertToHex($number idiv 16), te:convertToHex($number mod 16))
};

(:~ Decode escaped unicode into plain Unicode.
   Example invocation:
    te:unescapeUnicode("And \u041f\u0435\u0440\u043b? It's Perl, too.") :)
declare function te:unescapeUnicode($string as xs:string) (:as xs:string:) {
  let $encodings := fn:analyze-string($string, "\\u....")/element()
  return fn:string-join(
    for $e in $encodings
    return 
      if (fn:string(fn:node-name($e)) eq "s:match") then 
        fn:codepoints-to-string(xs:integer(te:convertToDecimal(fn:substring($e, 3))))
      else $e/text()
  )
};

(:~ TODO -- Make more random :)
declare function te:getRandomTriple() {
  let $query := 'SELECT * WHERE { ?s ?p ?o . } ORDER BY ?p LIMIT ' || xdmp:random() mod 100
  let $results := sem:sparql-values($query, map:map() )
  let $randomTriple := map:get($results, "o")[fn:last()]
  return $randomTriple
};





declare function te:get(
    $context as map:map,
    $params  as map:map
) as document-node()* 
{
  let $output-types := map:put($context,"output-types","application/json")
  let $ids  := json:array()
  let $rels := json:array()


  (: Get the incoming node, or default to some random node :)
  let $subjectId := 
    if (map:get($params, "node")) then map:get($params,"node")
    else te:getRandomTriple()
  let $subjectLabel := fn:replace(te:unescapeUnicode(te:removeNamespace($subjectId)), '^"(.*)"$', '$1')

  (: Query the immediately connected triples :)
  let $querySubject := 'SELECT * WHERE { ?s ?p ?o . }'
  let $queryObject  := 'SELECT * WHERE { ?o ?p ?s . }'
  let $bindings := ( map:entry("s", sem:iri($subjectId)) )
  let $subjectItems := sem:sparql-values($querySubject, $bindings)
  let $objectItems  := sem:sparql-values($queryObject,  $bindings)

  (: Construct a document to return to the client :)
  let $nodes := ( 
    fn:distinct-values((
      $subjectId
      ,
      for $i in $subjectItems
      return map:get($i, "o")
      ,
      for $i in $objectItems
      return map:get($i, "o")
    )))
  
  let $_ :=
    for $n in $nodes
    let $id := json:object-define( ("id", "label") )
    let $label := fn:replace(te:unescapeUnicode(fn:tokenize($n, "/")[fn:last()]), '"', "")
    let $_ := map:put($id, "id",    $n)
    let $_ := map:put($id, "label", $label )
    return if (te:isUnique("node", $n)) then json:array-push($ids, $id) else ()
  let $_ := (
    for $i in $subjectItems
    let $virtualNodeId := map:get($i, "p")
    
    let $rel := json:object-define( ("from", "to") )
    let $_   := map:put($rel, "from", $subjectId)
    let $_   := map:put($rel, "to",   $virtualNodeId)
    let $_   := map:put($rel, "color", $virtualNodeId)
    
    let $virtualNode := json:object-define( ("id", "label") )
    let $_ := map:put($virtualNode, "id",    $virtualNodeId)
    let $_ := map:put($virtualNode, "label", fn:replace(te:unescapeUnicode(fn:tokenize($virtualNodeId, "/")[fn:last()]), '"', "") )
    let $_ := map:put($virtualNode, "shape", "box")
    let $_ := map:put($virtualNode, "color", "lightgray")
    
    let $virtualRel := json:object-define( ("from", "to") )
    let $_ := map:put($virtualRel, "from", $virtualNodeId)
    let $_ := map:put($virtualRel, "to",   map:get($i, "o"))
    let $_ := map:put($virtualRel, "color", $virtualNodeId)
    
    let $_ := if (te:isUnique( "node", $virtualNodeId )) then json:array-push($ids, $virtualNode) else ()
    let $_ := if (te:isUnique( "edge", map:get($i, "o") )) then json:array-push($rels, $virtualRel) else ()
    return    if (te:isUnique( "edge", $virtualNodeId )) then json:array-push($rels, $rel) else ()

    ,
    for $i in $objectItems
    let $virtualNodeId := map:get($i, "p")

    let $rel := json:object-define( ("from", "to") )
    let $_   := map:put($rel, "from", map:get($i, "o"))
    let $_   := map:put($rel, "to",   $virtualNodeId)
    let $_   := map:put($rel, "color", $virtualNodeId)
    
    let $virtualNode := json:object-define( ("id", "label") )
    let $_ := map:put($virtualNode, "id",    $virtualNodeId)
    let $_ := map:put($virtualNode, "label", fn:replace(te:unescapeUnicode(fn:tokenize($virtualNodeId, "/")[fn:last()]), '"', "") )
    let $_ := map:put($virtualNode, "shape", "box")
    let $_ := map:put($virtualNode, "color", "lightgray")
    
    let $virtualRel := json:object-define( ("from", "to") )
    let $_ := map:put($virtualRel, "from", $virtualNodeId)
    let $_ := map:put($virtualRel, "to",   $subjectId)
    let $_ := map:put($virtualRel, "color", $virtualNodeId)
    
    let $_ := if (te:isUnique( "node", $virtualNodeId )) then json:array-push($ids, $virtualNode) else ()
    let $_ := if (te:isUnique( "edge", $virtualNodeId )) then json:array-push($rels, $virtualRel) else ()
    return    if (te:isUnique( "edge", map:get($i, "o") )) then json:array-push($rels, $rel) else ()
  )

  return document { 
    xdmp:to-json(
      fn:distinct-values(($ids, $rels))
    )
  }
  
};

