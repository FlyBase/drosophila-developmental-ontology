prefix owl: <http://www.w3.org/2002/07/owl#>
prefix obo: <http://purl.obolibrary.org/obo/>

DELETE {
	?term <http://purl.obolibrary.org/obo/IAO_0000115> ?definition .
}
WHERE {
  {
    ?term a owl:Class .
		?term <http://purl.obolibrary.org/obo/IAO_0000115> ?definition .
		?term owl:equivalentClass ?eq .
  }
  FILTER(STR(?definition) = "." && isIRI(?term) && regex(str(?term), "http://purl.obolibrary.org/obo/FBdv_"))
}