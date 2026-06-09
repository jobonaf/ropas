test_that(".opas_resolve_bearer_token accepts valid ropas_auth", {
  auth <- structure(
    list(
      token = "abc123",
      refresh_token = "refresh123",
      expires_at = Sys.time() + 3600
    ),
    class = "ropas_auth"
  )
  
  expect_equal(
    .opas_resolve_bearer_token(auth = auth),
    "abc123"
  )
})

test_that(".opas_resolve_bearer_token rejects auth and token together", {
  auth <- structure(
    list(
      token = "abc123",
      refresh_token = "refresh123",
      expires_at = Sys.time() + 3600
    ),
    class = "ropas_auth"
  )
  
  expect_error(
    .opas_resolve_bearer_token(auth = auth, token = "xyz"),
    "Use only one of `auth` or `token`"
  )
})

test_that(".opas_resolve_bearer_token rejects malformed auth", {
  expect_error(
    .opas_resolve_bearer_token(auth = list(token = "abc")),
    "`auth` must be an object returned by opas_auth"
  )
  
  bad_auth <- structure(
    list(
      token = "",
      refresh_token = "refresh123",
      expires_at = Sys.time() + 3600
    ),
    class = "ropas_auth"
  )
  
  expect_error(
    .opas_resolve_bearer_token(auth = bad_auth),
    "valid access token"
  )
})

test_that(".opas_resolve_bearer_token rejects expired auth", {
  auth <- structure(
    list(
      token = "abc123",
      refresh_token = "refresh123",
      expires_at = Sys.time() - 10
    ),
    class = "ropas_auth"
  )
  
  expect_error(
    .opas_resolve_bearer_token(auth = auth),
    "expired or close to expiry"
  )
})

test_that(".opas_resolve_bearer_token accepts raw token", {
  expect_equal(
    .opas_resolve_bearer_token(token = "abc123"),
    "abc123"
  )
  
  expect_error(
    .opas_resolve_bearer_token(token = ""),
    "non-empty character scalar"
  )
})