Rebol [
	title: "GitHub GraphQL API"
]

graphql: context [
	queries: [
		#include %queries.reb
	]

	header: make map! [
		Accept: "application/vnd.github+json"
		X-GitHub-Api-Version: 2022-11-28
	]
	header/Authorization: user's github-token-oldes

	request: func[
		query [string!]
		/v variables [map!]
		/local data retry result
	][
		data: make map! 8
		data/query: query
		if v [data/variables: variables]
		retry: 3
		while [retry > 0][
			result: try [
				load-json to-string write https://api.github.com/graphql reduce [
					'POST
					to block! any [header []]
					to-json data
				]
			]
			either not error? result [return result][
				print "GraphQl request error:"
				print result
				print ["^/RETRY:" retry: retry - 1] 
				
			]
		]
		none
	]
]
