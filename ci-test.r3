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
print as-yellow {Resolve the current user’s identity:}
probe github-query {query {viewer {login}}} none

;; Initialize variables for the GraphQL API:
variables: #[owner: "Oldes" repo: "Rebol3"]

print as-yellow {Retrieve the last 10 commits:}
probe github-query 'last-10-commits :variables

print as-yellow {List all releases:}
res: github-query 'releases :variables
foreach node res/data/repository/releases/edges [
	print [node/node/name node/node/url]
]

print as-yellow {Retrieve the data usage:}
probe github-query 'repo-disk-usage :variables

;- REST API tests...
;; Set the repository for REST API calls:
github-repo 'Oldes/Rebol3

print as-yellow {List all repository workflows:}
probe github-get/workflows

print 'DONE