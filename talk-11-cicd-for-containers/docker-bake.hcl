group "default" {
  targets = ["app"]
}

variable "REGISTRY" {
  default = "myregistry.azurecr.io"
}

variable "TAG" {
  default = "latest"
}

target "app" {
  context = "."
  dockerfile = "Dockerfile"
  tags = ["${REGISTRY}/talk-11:${TAG}"]
  cache-from = ["type=registry,ref=${REGISTRY}/talk-11:buildcache"]
  cache-to = ["type=registry,ref=${REGISTRY}/talk-11:buildcache,mode=max"]
  platforms = ["linux/amd64", "linux/arm64"]
  attest = [
    "type=provenance,mode=max",
    "type=sbom"
  ]
}
