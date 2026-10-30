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

	max-attempts: 3       ;; on network or 5xx errors
	retry-delay:  0:0:2

	request: func[
		"Sends a GraphQL query and returns the decoded response"
		query     [string! word!] "Query text or name of a predefined query"
		variables [map! none!]
		/local data tries result response
	][
		header/Authorization: *token
		if word? :query [
			unless result: select queries :query [
				print [as-purple "*** Unknown query:" as-red :query]
				return none
			]
			query: :result
		]
		data: make map! 8
		data/query: query
		if variables [data/variables: variables]
		tries: max-attempts
		forever [
			response: try [
				*send https://api.github.com/graphql reduce ['POST header to-json data]
			]
			case [
				error? response [] ;; network error, retry
				response/1 >= 500 [] ;; server error, retry
				response/1 >= 400 [
					fail ajoin ["GitHub GraphQL error " response/1 ": " to string! response/3]
				]
				true [
					result: load-json to string! response/3
					;; partial data with errors is returned, only full failures raise
					if all [block? result/errors  none? result/data][
						fail ajoin ["GitHub GraphQL error: " result/errors/1/message]
					]
					return result
				]
			]
			if 0 >= tries: tries - 1 [
				if error? response [do response]
				fail ajoin ["GitHub GraphQL error " response/1 ": " to string! response/3]
			]
			wait retry-delay
		]
	]

	*send: func[
		"Sends an HTTP request and returns [status headers body]"
		url     [url!]
		request [block!]
	][
		write/all url request
	]
]
