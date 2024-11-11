Rebol [
	title: "Rebol/GitHub CI test"
]

;; Initialize the user with a GitHub token:
set-user github-test

print ["Running test on Rebol build:" mold to-block system/build]
system/options/quiet: false
system/options/log/rebol: 4
system/options/log/http: 0

;; Ensure a fresh GitHub extension is loaded:
try [system/modules/github: none]
;; Set the modules directory to the build location:
system/options/modules: join what-dir %build/

print as-yellow {Import the GitHub module:}
import 'github

;- GraphQL API tests...
print-horizontal-line
print as-yellow {Resolve the current user’s identity:}
probe github-query {query {viewer {login}}} none

print-horizontal-line
;; Initialize variables for the GraphQL API:
variables: #[owner: "Oldes" repo: "Rebol3"]
n: 1
print as-yellow {Retrieve the last 10 commits:}
resolved: github-query 'last-10-commits :variables
;; Resolved commits are stored deep inside a structure... 
history: resolved/data/repository/defaultBranchRef/target/history
foreach edge history/edges [
	print [pad ++ n 5 edge/node/committedDate edge/node/messageHeadline]
]
;; Resolve following commits if there are any
while [
	history/pageInfo/hasNextPage
][
	print as-yellow {Retrieve the next 100 commits:}
	;; Modify the variables value with the cursor where to continue
	probe variables/after: history/pageInfo/endCursor
	resolved: github-query 'next-100-commits :variables
	;; Again... we need just the history deep inside the resolved structure
	history: resolved/data/repository/defaultBranchRef/target/history
	foreach edge history/edges [
		print [pad ++ n 5 edge/node/committedDate edge/node/messageHeadline]
	]
	;; Limit the output as this is just an example! 
	if n > 200 [ break ]
]

print-horizontal-line
print as-yellow {List all releases:}
res: github-query 'releases :variables
foreach node res/data/repository/releases/edges [
	print [node/node/name node/node/url]
]

print-horizontal-line
print as-yellow {Retrieve the data usage:}
probe github-query 'repo-disk-usage :variables


print-horizontal-line
;- REST API tests...
;; Set the repository for REST API calls:
github-repo 'Oldes/Rebol3

print as-yellow {List all repository workflows:}
probe github-get/workflows

print 'DONE