bats_load_library "bats-support"
bats_load_library "bats-assert"

function setup_file() {
    cd $BATS_TEST_DIRNAME

    export PATH="$PATH:$BATS_TEST_DIRNAME/helpers/"

    export ASSERT=$(mktemp)
    echo "{}" > $ASSERT

    bazel run :auth $ASSERT &
    export REGISTRY_PID=$!
    sleep 1
    bazel run :push -- --repository localhost:1447/empty_image
}

function teardown_file() {
    bazel shutdown
    kill $REGISTRY_PID
}


function setup() {
    export DOCKER_CONFIG=$(mktemp -d)
    echo "{}" > $ASSERT
}


@test "plain text" {
    cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "auths": {
    "localhost:1447": { "username": "test", "password": "test" }
  }
}
EOF
    echo '{"Authorization": ["Basic dGVzdDp0ZXN0"]}' > $ASSERT
    run bazel build @empty_image//... --repository_cache=$BATS_TEST_TMPDIR
    assert_success
}

@test "plain text base64" {
    cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "auths": {
    "http://localhost:1447": { "auth": "dGVzdDp0ZXN0" }
  }
}
EOF
    echo '{"Authorization": ["Basic dGVzdDp0ZXN0"]}' > $ASSERT
    run bazel build @empty_image//... --repository_cache=$BATS_TEST_TMPDIR
    assert_success
}

@test "plain text https" {
    cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "auths": {
    "https://localhost:1447": { "username": "test", "password": "test" }
  }
}
EOF
    echo '{"Authorization": ["Basic dGVzdDp0ZXN0"]}' > $ASSERT
    run bazel build @empty_image//... --repository_cache=$BATS_TEST_TMPDIR
    assert_success
}

@test "credstore" {
    cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "auths": { "localhost:1447": {} },
  "credsStore": "oci"
}
EOF
    echo '{"Authorization": ["Basic dGVzdGluZzpvY2k="]}' > $ASSERT
    run bazel build @empty_image//... --repository_cache=$BATS_TEST_TMPDIR
    assert_success
}

@test "credstore misbehaves" {
    cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "auths": { "localhost:1447": {} },
  "credsStore": "evil"
}
EOF
    run bazel build @empty_image//... --repository_cache=$BATS_TEST_TMPDIR
    assert_failure
    assert_output -p "can't run at this time" "ERROR: credential helper failed:"
}

@test "credstore missing" {
    cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "auths": { "localhost:1447": {} },
  "credsStore": "missing"
}
EOF
    run bazel build @empty_image//... --repository_cache=$BATS_TEST_TMPDIR
    assert_failure
    assert_output -p "exec: docker-credential-missing: not found" "ERROR: credential helper failed:"
}