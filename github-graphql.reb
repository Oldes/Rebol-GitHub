Rebol [
	title: "GitHub GraphQL API"
]

graphql: context [
	queries: object [
		#include %queries.reb
	]

	header: make map! [
		Accept: "application/vnd.github+json"
		X-GitHub-Api-Version: "2022-11-28"
	]

	request: func[
		query [string! word!]
		variables [map! none!]
		/local data retry result
	][
		if none? header/Authorization: user's github-token [
			do make error! "Authorization token (github-token) is missing!"
		]
		if word? :query [
			result: select queries :query
			unless result [
				print [as-purple "*** Unknown query:" as-red :query]
				return none 
			]
			query: :result
		]
		data: make map! 8
		data/query: query
		if variables [data/variables: variables]
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
