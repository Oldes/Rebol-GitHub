Rebol [title: "user options used in CI tests"]

all [
    print "Create the test user, if not exists..."
    attempt [set-user/n/p github-test any [get-env 'REBOL_SAFE_PASS "test"]]
    print "Add github token..."
    put system/user/data 'github-token get-env 'REBOL_GITHUB_TEST_TOKEN
    print "Force save..."
    update system/user/data
    print "Token ready."
]
