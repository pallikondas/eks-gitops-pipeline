terraform {
  backend "s3" {
    # Configure bucket, key, and region through terraform init -backend-config.
    # The bucket must exist before the first apply and must not be managed by this state.
    use_lockfile = true
  }
}