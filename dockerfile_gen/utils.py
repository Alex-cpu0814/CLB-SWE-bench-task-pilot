"""Helpers for validating and preparing generator inputs."""

import re

from swebench.utils import generate_heredoc_delimiter

from .constants import TEST_PATCH_DELIMITER


def validate_base_image(instance_id: str, base_image: str) -> None:
    slug = instance_id.replace("__", "_1776_")
    name = re.escape(f"yutu0814/clb.base.x86_64.{slug}:latest@sha256:")
    if not isinstance(base_image, str) or not re.fullmatch(name + "[0-9a-f]{64}", base_image):
        raise ValueError(f"Invalid pinned Base image for {instance_id}")


def prepare_test_patch(instance_id: str, test_patch: str) -> str:
    """Normalize line endings and guard the shell heredoc against early termination."""
    test = test_patch.replace("\r\n", "\n").rstrip("\n")
    if not test or TEST_PATCH_DELIMITER in test.splitlines():
        raise ValueError(f"Cannot embed test patch for {instance_id}")
    return test


def copy_inline(content: str, target: str) -> str:
    """Add a literal file to the Dockerfile without a companion build-context file."""
    if not content.endswith("\n"):
        raise ValueError(f"Inline Dockerfile content must end with a newline: {target}")
    delimiter = generate_heredoc_delimiter(content)
    return f"\nCOPY --chmod=0644 <<'{delimiter}' {target}\n{content}{delimiter}\n"
