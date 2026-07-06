group "default" {
  targets = ["app"]
}

variable "REGISTRY" {
  default = "myregistry.azurecr.io"
}

variable "TAG" {
  default = "latest"
}

variable "NETSKOPE_CERT" {
  default = ""
}

target "app" {
  context = "."
  dockerfile = "Dockerfile"
  # Pass NETSKOPE_CERT=/path/to/cert.crt to trust a corporate CA without baking it into any layer.
  secret = NETSKOPE_CERT != "" ? ["id=netskope_cert,src=${NETSKOPE_CERT}"] : []
  tags = ["${REGISTRY}/talk-11:${TAG}"]
  cache-from = ["type=registry,ref=${REGISTRY}/talk-11:buildcache"]
  cache-to = ["type=registry,ref=${REGISTRY}/talk-11:buildcache,mode=max"]
  platforms = ["linux/amd64", "linux/arm64"]
  attest = [
    "type=provenance,mode=max",
    "type=sbom"
  ]
}
