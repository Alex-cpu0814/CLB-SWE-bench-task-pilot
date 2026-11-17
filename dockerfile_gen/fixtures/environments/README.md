# Source-build recipes

Each `<instance_id>.Dockerfile` is a template for `tasks/<instance_id>/Dockerfile`.
The generator replaces `@BASE@` and `@INSTANCE@` from `task.yaml`; all other
build arguments have defaults. Missing recipes are errors, with no fallback to
an existing CLB task image.

The recipes were migrated from the original CLB per-task Dockerfiles and their
build configurations. Source and dependency archives previously prepared by
local wrappers are now replaced with depth-one Base checkouts, public artifact
downloads, and inline build steps. Downloaded Java artifacts have recorded
SHA-256 checks. For Kotlin 1.5.21, the checksum comes from the
[upstream release](https://github.com/JetBrains/kotlin/releases/tag/v1.5.21).
junixsocket 163 incorporates its former bootstrap Dockerfile into the build
and copies the legacy runtime from a public CentOS stage.

Only public build inputs enter these environments. `gold.patch`, `test.patch`,
test-selection manifests and evaluation runners are not copied into them.
Project tests already present at the Base revision remain part of the source.
The evaluation fixtures are supplied by `eval.sh` during grading.

All 72 recipes are present; this does not mean all 72 builds have been qualified.
See [validation status](../../../docs/validation.md) before replacing a published
image. Download locations and historical OS repositories still need to work
when a build is actually executed. OS package resolution can change even when
the base image is pinned, so subsequent qualification must compare toolchain
and dependency versions with the existing environments.
