[![rebol-github](https://github.com/user-attachments/assets/55bbab17-9ccd-4272-bac4-953fdeb92b7a)](https://github.com/Oldes/Rebol-Github)

[![Rebol-GitHub CI](https://github.com/Oldes/Rebol-GitHub/actions/workflows/main.yml/badge.svg)](https://github.com/Oldes/Rebol-GitHub/actions/workflows/main.yml)
[![Gitter](https://badges.gitter.im/rebol3/community.svg)](https://app.gitter.im/#/room/#Rebol3:gitter.im)
[![Zulip](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://rebol.zulipchat.com/)

# Rebol/GitHub

GitHub APIs ([GraphQL](https://docs.github.com/en/graphql) and [REST](https://docs.github.com/en/rest?apiVersion=2022-11-28)) module for [Rebol3](https://github.com/Oldes/Rebol3) (version 3.14.1 and higher)

## Configuration

This module expects the `github-token` value to be present in the user's data. A new user and token can be set using code like:
```rebol
set-user/n Test ;; Creates or loads data for the Test user (prompts for a password if needed)

if none? user's github-token [
	;; If no GitHub token is stored, add a new token:
	put system/user/data 'github-token "token 113d8...be2"
	
	;; Save updated data to disk:
	update system/user/data
]

;; Once the GitHub token is stored, one can import the module:
import 'github
```

## GraphQL API Usage example

```rebol
;; Initialize variables for the GraphQL API:
data: #[owner: "Oldes" repo: "Rebol3"]

;; Resolve the current user’s identity:
probe github-query {query {viewer {login}}} none

;; Retrieve the last 10 commits:
probe github-query 'last-10-commits :data

;; Paging queries (`next-100-commits`, `next-100-issues`) take the cursor in `after`:
data/after: "..."
```

## REST API Usage example

```rebol
;; List all of supported `get`, `post`, `edit` and `run` functions:
help github-get
help github-post
help github-edit
help github-run

;; Set the repository for REST API calls:
github-repo 'Oldes/Rebol3

;; Retrieve all repository workflows:
probe github-get/workflows

;; Trigger a workflow (default ref is `main`):
github-run/workflow/ref/with "main.yml" "master" #[level: "debug"]
```

## Error handling

REST calls raise an error with GitHub's message on 4xx/5xx responses.
GraphQL requests raise an error on 4xx responses, or when the response contains
`errors` without any `data`. Network and 5xx errors are retried a few times first.

## Testing

Offline unit tests (no network, no token needed):
```
rebol3 unit-tests.r3
```
Live API tests (needs a user with `github-token`): `ci-test.r3`

Check the [CI-test script](https://github.com/Oldes/Rebol-GitHub/blob/main/ci-test.r3) for more examples.
