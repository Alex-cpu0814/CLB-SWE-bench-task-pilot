"""Generate Dockerfile and eval.sh for CLB tasks."""

import re

from . import java_c, python_c
from .templates import EVAL_SCRIPT, PILOT_EVAL_SCRIPT


def validate_base_image(instance_id, base_image):
    slug = instance_id.replace("__", "_1776_")
    name = re.escape(f"yutu0814/clb.base.x86_64.{slug}:latest@sha256:")
    if not isinstance(base_image, str) or not re.fullmatch(name + "[0-9a-f]{64}", base_image):
        raise ValueError(f"Invalid pinned Base image for {instance_id}")


def render_files(instance_id, cohort, base_commit, base_image, test_patch):
    """Render both task files from metadata, the pinned image, and the test patch."""
    validate_base_image(instance_id, base_image)
    if not isinstance(base_commit, str) or not re.fullmatch("[0-9a-f]{40}", base_commit):
        raise ValueError(f"Invalid Base commit for {instance_id}")
    test = test_patch.replace("\r\n", "\n").rstrip("\n")
    if not test or "CLB_TEST_PATCH" in test.splitlines():
        raise ValueError(f"Cannot embed test patch for {instance_id}")

    if cohort in python_c.COHORTS:
        pilot_normalizer = python_c.PILOT_NORMALIZERS.get(instance_id)
    elif cohort in java_c.COHORTS:
        pilot_normalizer = java_c.PILOT_NORMALIZERS.get(instance_id)
    else:
        raise ValueError(f"Unknown cohort for {instance_id}: {cohort}")

    if pilot_normalizer:
        dockerfile = f"FROM {base_image}\nCOPY runtime/ /opt/clb-pilot/\n"
        script = PILOT_EVAL_SCRIPT.replace("@NORMALIZE@", pilot_normalizer)
    else:
        dockerfile = f"FROM {base_image}\nCOPY runtime/ /benchmark/\n"
        script = EVAL_SCRIPT.replace("@MOUNTS@", java_c.EVAL_SETUP.get(instance_id, ""))
        if cohort in java_c.COHORTS:
            dockerfile += java_c.DOCKER_SETUP.get(instance_id, "")
            excluded = " -e bin" if instance_id in java_c.PRESERVE_BIN else ""
            dockerfile += f"RUN git -C /testbed clean -fdx{excluded}\n"

    script = script.replace("@BASE@", base_commit).replace("@TEST@", test)
    return {"Dockerfile": dockerfile.encode("utf-8"), "eval.sh": script.encode("utf-8")}
