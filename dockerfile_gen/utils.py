"""Helpers for validating and preparing generator inputs."""

from swebench.utils import generate_heredoc_delimiter

from .constants import END_TEST_OUTPUT, TEST_PATCH_DELIMITER


def validate_shared_image(instance_id: str, image: str, image_name: str) -> None:
    slug = instance_id.replace("__", "_1776_").lower()
    if image != f"yutu0814/sweb.eval.x86_64.{slug}:latest" or image_name != image:
        raise ValueError(f"image and image_name must use the same CLB image tag for {instance_id}")


def prepare_test_patch(instance_id: str, test_patch: str) -> str:
    """Normalize line endings and guard the shell heredoc against early termination."""
    test = test_patch.replace("\r\n", "\n").rstrip("\n")
    if not test or TEST_PATCH_DELIMITER in test.splitlines():
        raise ValueError(f"Cannot embed test patch for {instance_id}")
    return test


def write_inline(content: str, target: str) -> str:
    """Write an evaluation fixture after the candidate patch has been applied."""
    # SWE-bench strips these shell lines and inserts grading at the output marker.
    removed_lines = {"#!/bin/bash", "set -uxo pipefail"}
    if (
        not content.endswith("\n")
        or removed_lines.intersection(content.splitlines())
        or END_TEST_OUTPUT in content
    ):
        raise ValueError(f"Cannot embed evaluation fixture: {target}")
    delimiter = generate_heredoc_delimiter(content)
    return f"cat > {target} <<'{delimiter}' || fail 'Cannot write {target}'\n{content}{delimiter}\n"
